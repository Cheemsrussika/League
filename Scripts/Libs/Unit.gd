extends CharacterBody2D
class_name Unit

# --- SIGNALS ---
signal unit_died(unit: Unit)
signal damage_taken(source: Node, amount: float, type: String)
signal stats_updated(text: String)
@export_group("Loot")
@export var drop_items: Array[ItemData] = []
@export var drop_chances: Array[float] = []
# --- CONSTANTS & PRELOADS ---
const FLOATING_TEXT_SCENE = preload("res://Screen/floating_text.tscn")

@export_group("Reward")
@export var gold_reward: float = 210.0
@export var exp_reward: float = 100.0
# --- ENUMS ---
@export_group("Unit setting")
enum UnitType { CHAMPION, MINION, MONSTER, TOWER, RESOURCE }
@export var unit_type: UnitType = UnitType.MINION
enum Team { BLUE, RED, NEUTRAL, PURPLE }
@export var team: Team = Team.NEUTRAL

enum Stat {
	HP, HP5, AR, MR, SLOWRES,
	AD, AP, AS, MS, MANA, MANARG, ENERGY, 
	AH, CRIT, CRIT_DMG, RANGE,
	ARMOR_PEN, MAGIC_PEN, 
	TENACITY, OMNIVAMP, PHYSIC_VAMP, LIFE_STEAL,
	GOLD_GEN, GOLD, SPELLHASTE, INC_PHYS_DMG_MOD, 
	INC_MAGIC_DMG_MOD, INC_ALL_DMG_MOD, HEAL_AND_SHIELD,
	ARMOR_PEN_PERCENT, MAGIC_PEN_PERCENT, OUTGOING_DMG_MOD,SKILL_DAMAGE_MULT
}

# Maps Enum keys to String keys for the dictionaries
const STAT_MAP = {
	Stat.HP: "health", Stat.HP5: "health_regen", Stat.AR: "armor",
	Stat.MR: "magic_res", Stat.SLOWRES:"Slow_res",
	Stat.AD: "attack_damage", Stat.AP: "ability_power", Stat.AS: "attack_speed", 
	Stat.MS: "move_speed", Stat.MANA:"Mana", Stat.MANARG:"Mana_Regen",
	Stat.ENERGY:"Energy", Stat.AH: "ability_haste", Stat.CRIT: "crit_chance",
	Stat.CRIT_DMG: "crit_damage", Stat.RANGE: "attack_range",
	Stat.ARMOR_PEN: "armor_pen", Stat.MAGIC_PEN: "magic_pen",
	Stat.TENACITY: "tenacity", Stat.OMNIVAMP: "omnivamp",
	Stat.PHYSIC_VAMP:"Physic_Vamp", Stat.LIFE_STEAL: "life_steal",
	Stat.GOLD_GEN: "gold_gen", Stat.GOLD:"Gold", Stat.SPELLHASTE:"Spell_haste",
	Stat.INC_PHYS_DMG_MOD: "phys_dmg_take_modi",
	Stat.INC_MAGIC_DMG_MOD: "magic_dmg_take__modi",
	Stat.INC_ALL_DMG_MOD:  "all_dmg_take_modi", Stat.HEAL_AND_SHIELD:"heal_and_shield_power",
	Stat.ARMOR_PEN_PERCENT:"armor_pen_percent", Stat.MAGIC_PEN_PERCENT:"magic_pen_percent",
	Stat.OUTGOING_DMG_MOD: "dmg_dealt_modifier",Stat.SKILL_DAMAGE_MULT: "skill_damage_multiplier"
}

# --- STAT VARIABLES ---
@export var base_stats: Dictionary = {
	"health": 500.0, "health_regen": 5.0, "armor": 30.0, "magic_res": 30.0,
	"attack_damage": 60.0, "ability_power": 0.0, "attack_speed": 0.625,
	"move_speed": 330.0, "attack_range": 175.0, "armor_pen": 0.0, "magic_pen": 0.0,
	"Slow_res": 0.0, "Mana": 100.0, "Mana_Regen": 2.0, "Energy": 0.0, 
	"crit_chance": 0.0, "crit_damage": 1.75, "omnivamp": 0.0, "life_steal": 0.0,
	"phys_dmg_take_modi": 1.0, "magic_dmg_take__modi": 1.0, 
	"all_dmg_take_modi": 0.0, "gold_gen": 5.0,"dmg_dealt_modifier":0.0,"skill_damage_multiplier":1.0
}

var current_health: float = 0.0
var bonus_stats: Dictionary = {}
var stat_modifiers: Dictionary = {} # Temporary mods (buffs/debuffs)
var percent_modifiers: Dictionary = {}
# --- COMPONENTS ---
# Defined here so Unit logic can see it. Champion will assign it.
var inventory: Node = null 

# --- SHIELDS ---
var active_shields: Array[Dictionary] = [] 
var total_shield_amount: float = 0.0
enum ShieldType { ALL=0, PHYSICAL=1, MAGIC=2 }
enum ShieldDecay { NONE, TIMEOUT, DECAY_OVER_TIME }

# --- COMBAT STATE ---
var is_dead: bool = false
var damage_done: float = 0.0
var last_combat_time: int = 0
var attack_cooldown_timer: float = 0.0
var current_target: Node2D = null 
var nav_target = null

# --- STATUS EFFECT SYSTEM ---

var is_slowed: bool = false
@export var passive_effects: Array[ItemEffect] 
@onready var status_container: Node = $StatusContainer # Ensure this child node exists in Scene!

# --- LIFECYCLE ---
func _ready():
	# Initialize Dictionaries
	for stat_enum in STAT_MAP:
		var stat_key = STAT_MAP[stat_enum]
		if not base_stats.has(stat_key): base_stats[stat_key] = 0.0
		if not bonus_stats.has(stat_key): bonus_stats[stat_key] = 0.0
	for key in base_stats.keys():
		bonus_stats[key] = 0.0
		stat_modifiers[key] = 0.0

	current_health = get_total(Stat.HP)

func _process(delta: float):
	# Base class can handle generic updates if needed
	_handle_shields(delta)
	handle_regeneration(delta)

# --- SHIELD LOGIC ---
func add_shield(amount: float, duration: float, type: int = ShieldType.ALL, decay_mode: int = ShieldDecay.TIMEOUT, shield_id: String = ""):
	# 1. Check if a shield with this ID already exists
	if shield_id != "":
		for s in active_shields:
			if s.has("id") and s["id"] == shield_id:
				# REFRESH LOGIC:
				# Option A: Take the highest amount (standard)
				s["amount"] = max(s["amount"], amount) 
				s["max_amount"] = amount
				# Option B: Reset the duration
				s["duration"] = duration
				s["max_duration"] = duration
				
				_recalc_total_shield()
				return # Stop here! Don't add a new shield.

	# 2. If no ID match found (or no ID provided), create a new one
	var new_shield = {
		"id": shield_id, # Store the ID!
		"amount": amount, 
		"max_amount": amount,
		"duration": duration, 
		"max_duration": duration,
		"type": type, 
		"decay_mode": decay_mode
	}
	active_shields.append(new_shield)
	_recalc_total_shield()
	
func _handle_shields(delta):
	var dirty = false
	for i in range(active_shields.size() - 1, -1, -1):
		var s = active_shields[i]
		if s["max_duration"] > 0:
			s["duration"] -= delta
			if s["decay_mode"] == ShieldDecay.DECAY_OVER_TIME:
				var percent_left = s["duration"] / s["max_duration"]
				s["amount"] = s["max_amount"] * percent_left
				dirty = true
			if s["duration"] <= 0:
				active_shields.remove_at(i)
				dirty = true
	if dirty: _recalc_total_shield()

func _recalc_total_shield():
	total_shield_amount = 0.0
	for s in active_shields:
		total_shield_amount += s["amount"]

# --- CORE STAT CALCULATION ---
# --- CORE STAT CALCULATION ---
func get_total(s: Stat) -> float:
	if not STAT_MAP.has(s): return 0.0
	var key = STAT_MAP[s]
	
	var base_val = base_stats.get(key, 0.0)
	var bonus_val = bonus_stats.get(key, 0.0)
	
	# 1. Get our dynamic values
	var flat_mod = stat_modifiers.get(key, 0.0)
	var percent_mod = percent_modifiers.get(key, 0.0)
	
	# 2. Add all flat values together first
	var total = base_val + bonus_val + flat_mod

	# 3. Apply percentage multipliers (Buffs are positive, Debuffs are negative)
	total = total * (1.0 + percent_mod)

	# Special Logic for Health/Mana Regen (Since their base math is unique)
	if key == "health_regen" or key == "Mana_Regen":
		var multiplier = 1.0 + (bonus_val / 100.0)
		total = (base_val * multiplier) + flat_mod

	return max(0.0, total)
func recalculate_stats():
	# 1. Clear both dictionaries from the previous frame
	stat_modifiers.clear()
	percent_modifiers.clear() # <- You were missing this!
	is_slowed = false
	
	# 2. Ask Items for stats
	if inventory and "items" in inventory:
		for item in inventory.items:
			if item and item.effects:
				for effect in item.effects:
					if effect.has_method("on_stat_calculation"):
						effect.on_stat_calculation(self)

	# 3. Read Stats from the Status Container
	if status_container:
		for status in status_container.get_children():
			if status.is_queued_for_deletion():
				continue
			
			if status.has_method("on_stat_calculation"):
				status.on_stat_calculation(self)
				
			# Check for Status Flags (Slows, etc)
			if status.get("type") == "slow":
				is_slowed = true

			# --- A. Grab the Flat Stats ---
			if "stats_to_buff" in status:
				for stat_enum in status.stats_to_buff:
					if STAT_MAP.has(stat_enum):
						var string_key = STAT_MAP[stat_enum] # Convert Enum (2) to String ("armor")
						var amount = status.stats_to_buff[stat_enum] * status.stacks
						DevMenu.add_log("StatBuff: %s + %s"%[string_key,amount])
						stat_modifiers[string_key] = stat_modifiers.get(string_key, 0.0) + amount
					
			# --- B. Grab the Percent Stats! ---
			if "percent_stats_to_buff" in status:
				for stat_enum in status.percent_stats_to_buff:
					if STAT_MAP.has(stat_enum):
						var string_key = STAT_MAP[stat_enum] # Convert Enum (2) to String ("armor")
						var amount = status.percent_stats_to_buff[stat_enum] * status.stacks
						percent_modifiers[string_key] = percent_modifiers.get(string_key, 0.0) + amount

	# 4. Visual Updates
	modulate = Color(0.5, 0.5, 1.0) if is_slowed else Color.WHITE

	if has_method("_refresh_ui_display"):
		call("_refresh_ui_display")
		
func modify_stat(stat_name: String, amount: float):
	if stat_modifiers.has(stat_name):
		stat_modifiers[stat_name] += amount
	else:
		stat_modifiers[stat_name] = amount

# --- DAMAGE LOGIC ---
func take_damage(raw_amount: float, dmg_type: String, source: Node, _is_crit:bool, _category: String = "spell"):
	if is_dead: return {"health_lost": 0, "mitigated": 0, "shield_soaked": 0}
	
	var mitigated_damage = _calculate_mitigation(raw_amount, dmg_type, source)
	var damage_after_shields = _absorb_damage_with_shields(mitigated_damage, dmg_type)
	
	var actual_health_lost = 0.0
	if damage_after_shields > 0:
		actual_health_lost = damage_after_shields
		current_health -= actual_health_lost
	
	var shield_soaked = mitigated_damage - actual_health_lost
	
	var result = {
		"raw": raw_amount,
		"mitigated": mitigated_damage,
		"health_lost": actual_health_lost,
		"shield_soaked": shield_soaked
	}
	if GameEvents:
		GameEvents.unit_damaged.emit(self, source, raw_amount)
	damage_taken.emit(source, mitigated_damage, dmg_type) 
	if current_health <= 0:
		die(source)
	return result

func _calculate_mitigation(amount: float, type: String, source: Node) -> float:
	if type == "true": return amount
	
	var defense_stat = 0.0
	var flat_pen = 0.0
	var percent_pen = 0.0
	var source_multiplier = 1.0
	
	if type == "physical":
		defense_stat = get_total(Stat.AR)
		if source:
			flat_pen = source.get_total(Stat.ARMOR_PEN)
			percent_pen = source.get_total(Stat.ARMOR_PEN_PERCENT)
	elif type == "magic":
		defense_stat = get_total(Stat.MR)
		if source:
			flat_pen = source.get_total(Stat.MAGIC_PEN)
			percent_pen = source.get_total(Stat.MAGIC_PEN_PERCENT)
			
	if percent_pen > 1.0: percent_pen /= 100.0
	if percent_pen > 0:
		defense_stat *= (1.0 - percent_pen)
	
	defense_stat = max(0.0, defense_stat - flat_pen)
	
	var multiplier = 100.0 / (100.0 + defense_stat) if defense_stat >= 0 else 2.0 - (100.0 / (100.0 - defense_stat))
	var dmg_mod = 1.0
	if type == "physical": dmg_mod = get_total(Stat.INC_PHYS_DMG_MOD)
	elif type == "magic": dmg_mod = get_total(Stat.INC_MAGIC_DMG_MOD)
	var all_mod = get_total(Stat.INC_ALL_DMG_MOD)
	
	if source:
		source_multiplier += source.get_total(Stat.OUTGOING_DMG_MOD)
		
	return amount * multiplier * max(0.0, dmg_mod + all_mod) * source_multiplier

func _absorb_damage_with_shields(damage: float, dmg_type: String) -> float:
	if active_shields.is_empty() or damage <= 0: return damage
	
	var damage_remaining = damage
	var dirty_ui = false
	var shield_candidates = []
	
	var incoming_type_enum = -1
	if dmg_type == "physical": incoming_type_enum = ShieldType.PHYSICAL
	if dmg_type == "magic": incoming_type_enum = ShieldType.MAGIC
	
	for s in active_shields:
		if s["amount"] <= 0: continue
		var can_block = false
		if s["type"] == ShieldType.ALL: can_block = true
		elif s["type"] == incoming_type_enum: can_block = true
		
		if can_block: shield_candidates.append(s)
			
	shield_candidates.sort_custom(func(a, b):
		var a_is_specific = (a["type"] != ShieldType.ALL)
		var b_is_specific = (b["type"] != ShieldType.ALL)
		if a_is_specific and not b_is_specific: return true
		if not a_is_specific and b_is_specific: return false
		if a["max_duration"] == -1: return false
		if b["max_duration"] == -1: return true 
		return a["duration"] < b["duration"]
	)
	
	for s in shield_candidates:
		if damage_remaining <= 0: break
		var absorb = min(s["amount"], damage_remaining)
		s["amount"] -= absorb
		damage_remaining -= absorb
		dirty_ui = true
		
	if dirty_ui: _recalc_total_shield()
	return damage_remaining


func die(killer) -> void:
	if is_dead: return   # Guard against double-death
	is_dead = true
 
	# Emit the signal — LootTableComponent listens to this
	unit_died.emit(self)
 
	# Trigger on_kill on the killer (existing logic)
	if killer and killer.has_method("on_kill_trigger"):
		killer.on_kill_trigger(self)


# This is the "Hook" that items will listen to
func on_kill_trigger(victim: Unit):
	var context = {"victim": victim}
	
	# Trigger Items
	if inventory and "items" in inventory:
		for item in inventory.items:
			if item:
				for effect in item.effects:
					if effect.has_method("on_kill"):
						effect.on_kill(self, context)
	
	# Trigger Skills/Passives (If you have them)
	# ... logic for skill passives ...
func handle_regeneration(delta):
	var max_hp = get_total(Stat.HP)
	var hp5 = get_total(Stat.HP5)
	
	if current_health < -50: current_health = 0
		
	if not is_dead and current_health < max_hp:
		current_health += (hp5 / 5.0) * delta
		if current_health > max_hp: current_health = max_hp

func _trigger_passive_effects(event_name: String, context: Dictionary) -> void:
	# 1. Trigger Inventory items (if the unit has an inventory)
	if inventory:
		inventory.trigger_global_event(event_name, context)
	for effect in passive_effects:
		if effect != null and effect.has_method(event_name):
			effect.call(event_name, self, context)
	if has_node("StatusContainer"):
		for status in $StatusContainer.get_children():
			if status.has_method(event_name):
				status.call(event_name, self, context)

# --- NEW STATUS EFFECT SYSTEM ---

func add_status(id: String, duration: float, stacks: int = 1, _type: int = 1, power: float = 0.0, _icon: String = ""):
	apply_status_effect(id, duration, stacks, power, self)

func apply_status_effect(id: String, duration: float, stacks: int = 1, power: float = 0.0, source: Node = null):
	if not status_container:
		push_error("Unit " + name + " has no StatusContainer node!")
		return
	var existing_node = status_container.get_node_or_null(id)
	if existing_node:
		if existing_node.has_method("refresh"):
			existing_node.refresh(duration, stacks, power)
	else:
		if not StatusLibrary:
			push_error("StatusLibrary Singleton not found!")
			return
		var effect_script = StatusLibrary.get_effect_script(id)
		if effect_script:
			var new_effect = effect_script.new()
			new_effect.name = id
			new_effect.id = id
			if "duration" in new_effect: new_effect.duration = duration
			if "stacks" in new_effect: new_effect.stacks = stacks
			if "power" in new_effect: new_effect.power = power
			if "source" in new_effect: new_effect.source = source
			status_container.add_child(new_effect)
			if new_effect.has_method("on_apply"):
				new_effect.on_apply(self)
	recalculate_stats()
func has_status(id: String) -> bool:
	if not status_container: return false
	return status_container.has_node(id)
	
#--Selection
# Add this to your unit/enemy/player script
func _input_event(viewport, event, shape_idx):
	# Check if it's a right mouse button click
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		
		# Tell the global manager that THIS unit is now the selected one
		GameManager.selected_unit = self
		DevMenu.add_log("Dev/Inspect Target Selected: %s"% GameManager.selected_unit.name)
		var inspect_ui = get_tree().get_first_node_in_group("inspect_panel")
		if inspect_ui:
			inspect_ui.open_panel(self)
