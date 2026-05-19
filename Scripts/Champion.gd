extends Unit
class_name Champion

# ==========================================
# --- SIGNALS ---
# ==========================================
signal gold_updated(amount: float)
signal level_updated(new_level: int)
signal status_damage_dealt(status_id: String, receipt: Dictionary)
signal stats_recalculated(unit: Unit)

# ==========================================
# --- ENUMS & DATA LOADING ---
# ==========================================
enum ResourceType { MANA, ENERGY, FURY, NONE }

@export var current_champion_data: Resource # Typed as Resource to prevent circular dependency errors
@onready var anim_player: AnimationPlayer = $AnimationPlayer # Adjust path as needed
@onready var sprite: Sprite2D = $Sprite2D
var portrait_texture: Texture2D
# ==========================================
# --- STATE VARIABLES ---
# ==========================================
var resource_type: ResourceType = ResourceType.MANA
var current_resource: float = 0.0

var hp_growth: float = 0.0
var mana_growth: float = 0.0
var ad_growth: float = 0.0
var armor_growth: float = 0.0
var mr_growth: float = 0.0
var as_growth_percent: float = 0.0
var accumulated_as_growth: float = 0.0 

var default_collision_mask: int
var active_passive: ChampionPassive = null

var level: int = 1
var experience: float = 0.0
var experience_to_next_level: float = 280.0

var gold: float = 10000.0:
	set(value):
		gold = value
		gold_updated.emit(gold)

# --- COMBAT & DASH STATE ---
var is_winding_up: bool = false
var windup_timer: float = 0.0
const WINDUP_PERCENT: float = 0.3

var dash_tween: Tween
var is_dashing: bool = false
var can_cancel_dash: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var dash_distance_remaining: float = 0.0
var current_dash_speed: float = 0.0
var dash_arrival_effects: Array = []
var dash_context: Dictionary = {}

var pending_skill_slot: SkillSlot = null

# --- CRIT SYSTEM ---
var crit_pity_bonus: float = 0.0
const PITY_INCREMENT: float = 0.05

# ==========================================
# --- COMPONENTS & NODE REFERENCES ---
# ==========================================

@onready var auto_attack_slot: SkillSlot = $Skills/AutoAttack
# Make sure you have a Skills Node with these slots!
@onready var skill_q: SkillSlot = $Skills/Skill_Q 
@onready var skill_t: SkillSlot = $Skills/Skill_T
@onready var skill_e: SkillSlot = $Skills/Skill_E
@onready var skill_r: SkillSlot = $Skills/Skill_R
@onready var skill_h: SkillSlot = $Skills/Skill_H

var combo_index: int = 0
var combo_reset_timer: float = 0.0
const COMBO_TIMEOUT: float = 2.0 # Resets to first attack if 1.5s pass without attacking
var auto_attack_sequence: Array[SkillData] = []

# ==========================================
# 1. ENGINE CALLBACKS & INITIALIZATION
# ==========================================
func _ready():
	super._ready() 
	unit_type = UnitType.CHAMPION 
	inventory = $InventoryComponent
	
	if current_champion_data and current_champion_data is ChampionData:
		initialize_from_data(current_champion_data)
			
	default_collision_mask = collision_mask

	if inventory:
		inventory.inventory_changed.connect(_on_inventory_updated)
		_on_inventory_updated()
		
func _physics_process(delta: float) -> void:
	_handle_shields(delta)
	handle_regeneration(delta) # Handles HP and Resource
	
	if is_dashing:
		_process_dash(delta)
		return # Skip all other movement logic while dashing!
		
	if attack_cooldown_timer > 0: 
		attack_cooldown_timer -= delta
	if combo_reset_timer > 0:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0:
			reset_combo()
	handle_gold_generation(delta)
func initialize_from_data(data: ChampionData) -> void:
	resource_type = data.resource_type as ResourceType
	if "champion_passive" in data and data.champion_passive:
		active_passive = data.champion_passive.duplicate()
		if active_passive.has_method("connect_combat_hooks"):
			active_passive.connect_combat_hooks(self)
	portrait_texture = data.portrait
	if "sprite_sheet" in data and data.sprite_sheet:
		sprite.texture = data.sprite_sheet
	# Map Base Stats (The "Item Way")
	base_stats[STAT_MAP[Stat.HP]] = data.base_hp
	current_health = data.base_hp

	base_stats[STAT_MAP[Stat.AD]] = data.base_ad
	base_stats[STAT_MAP[Stat.AR]] = data.base_armor
	base_stats[STAT_MAP[Stat.MR]] = data.base_mr
	base_stats[STAT_MAP[Stat.MS]] = data.base_ms
	base_stats[STAT_MAP[Stat.RANGE]] = data.base_range
	base_stats[STAT_MAP[Stat.MANA]] = data.base_resource
	base_stats[STAT_MAP[Stat.AS]] = data.base_as

	# Load Growth Stats
	hp_growth = data.hp_growth
	mana_growth = data.mana_growth
	ad_growth = data.ad_growth
	armor_growth = data.armor_growth
	mr_growth = data.mr_growth
	as_growth_percent = data.as_growth_percent
	
	# Inject Skill Resources into Slots
	if skill_q: skill_q.skill_data = data.q_skill
	if skill_t: skill_t.skill_data = data.t_skill
	if skill_e: skill_e.skill_data = data.e_skill
	if skill_r: skill_r.skill_data = data.r_skill
	if skill_h: skill_h.skill_data = data.h_skill
	if "auto_attack_sequence" in data:
		auto_attack_sequence = data.auto_attack_sequence
	if auto_attack_slot and auto_attack_sequence.size() > 0:
		auto_attack_slot.skill_data = auto_attack_sequence[0]
	# Initialize Resource starting value
	match resource_type:
		ResourceType.FURY, ResourceType.NONE: 
			current_resource = 0.0
		_: 
			current_resource = data.base_resource 

			
	for c_enum in data.primary_classes:
		var class_name_str = ItemData.ItemClass.keys()[c_enum]
		if not unit_tags.has(class_name_str):
			unit_tags.append(class_name_str)
			DevMenu.add_log("Champion Class Loaded: %s" % class_name_str)
			
	recalculate_stats()


# ==========================================
# 2. CORE COMBAT & TARGETING
# ==========================================
func set_chase_and_cast(target, slot):
	current_target = target
	pending_skill_slot = slot

func execute_combat_logic(delta: float):
	if is_dashing: 
		return
		
	if is_winding_up:
		velocity = Vector2.ZERO
		windup_timer -= delta
		if windup_timer <= 0:
			_complete_attack()
		return 

	# PRIORITY: Skill Chasing (For targeted Q/W/E/R abilities)
	if pending_skill_slot and is_instance_valid(current_target):
		var dist = global_position.distance_to(current_target.global_position)
		
		if dist <= pending_skill_slot.skill_data.cast_range:
			velocity = Vector2.ZERO 
			var target_data = {"target_unit": current_target, "target_position": current_target.global_position}
			pending_skill_slot.activate(self, target_data)
			pending_skill_slot = null 
			current_target = null 
		else:
			var move_spd = get_current_move_speed()
			velocity = global_position.direction_to(current_target.global_position) * move_spd
		
		move_and_slide()
		return 
			
	# NAVIGATION LOGIC (Left-Click Movement)
	if nav_target != null:
		var dist = global_position.distance_to(nav_target)
		if dist < 5.0:
			velocity = Vector2.ZERO
			nav_target = null 
		else:
			var move_spd = get_current_move_speed()
			velocity = global_position.direction_to(nav_target) * move_spd
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 2000 * delta)

	move_and_slide()

func advance_combo():
	if auto_attack_sequence.size() <= 1: return # No combo needed
	
	# Move to the next attack in the array, loop back to 0 if at the end
	combo_index = (combo_index + 1) % auto_attack_sequence.size()
	
	# Inject the new attack data into the slot
	auto_attack_slot.skill_data = auto_attack_sequence[combo_index]
	
	# Reset the timer so the player has 1.5 seconds to do the next attack
	combo_reset_timer = COMBO_TIMEOUT

func reset_combo():
	combo_index = 0
	if auto_attack_sequence.size() > 0:
		auto_attack_slot.skill_data = auto_attack_sequence[0]
		


func _start_windup(_target: Node2D):
	is_winding_up = true
	var aps = max(0.01, get_total(Stat.AS))
	var total_attack_time = 1.0 / aps
	windup_timer = total_attack_time * WINDUP_PERCENT
	
	# Scale AnimationPlayer speed dynamically
	if is_instance_valid(anim_player):
		anim_player.speed_scale = aps
		
		var anim_name = "attack_" + str(combo_index)
		
		if anim_player.has_animation(anim_name):
			anim_player.play(anim_name)
		else:
			anim_player.play("attack_0") # Fallback to first swing

func _complete_attack():
	is_winding_up = false 
	
	# 1. Fire the modular SkillData logic!
	if auto_attack_slot and auto_attack_slot.skill_data:
		# Determine where to aim. Default to mouse position for skillshots.
		var target_pos = get_global_mouse_position()
		
		# If we hard-locked onto a target, aim exactly at them instead
		if is_instance_valid(current_target):
			target_pos = current_target.global_position
			
		var target_data = {
			"target_position": target_pos,
			"target_unit": current_target # Might be null, and that's okay!
		}
		
		# Pull the trigger! This spawns your directional slash or projectile hitbox.
		auto_attack_slot.activate(self, target_data)
		
	# 2. Setup the next attack in the combo sequence
	advance_combo()
	
	# 3. Calculate recovery cooldown based on Attack Speed
	var aps = max(0.01, get_total(Stat.AS))
	var total_time = 1.0 / aps
	attack_cooldown_timer = total_time - (total_time * WINDUP_PERCENT)


# ==========================================
# 3. DAMAGE, SPELLCASTING & COMBAT MATH
# ==========================================

func on_skill_cast(ability_identifier: String, mana_cost: float = 0.0, is_toggle: bool = false):
	var context = {
		"ability_id": ability_identifier, "mana_cost": mana_cost,
		"is_toggle": is_toggle, "cast_time": Time.get_ticks_msec()
	}
	_trigger_passive_effects("on_ability_activated", context)

func deal_damage(target: Node2D, amount: float, type: String, category: String, is_crit: bool = false, skill_context: Dictionary = {}) -> float:
	var final_amount = amount
	if is_crit:
		final_amount *= get_total(Stat.CRIT_DMG) 

	var receipt = target.take_damage(final_amount, type, self, is_crit, category)
	var actual_lost = receipt["health_lost"]
	
	if actual_lost > 0:
		var context = {
			"target": target, 
			"amount": final_amount,
			"health_lost": actual_lost,
			"damage_type": type, 
			"category": category, 
			"is_crit": is_crit
		}
		context.merge(skill_context)

		_trigger_passive_effects("on_damage_dealt", context)
		
		# Consolidated Healing Calculations
		var total_heal = 0.0
		var healing_mult = 1.0
		if context.get("is_aoe", false): healing_mult = 0.33

		if type == "physical" and context.get("allow_lifesteal", false):
			total_heal += actual_lost * (get_total(Stat.LIFE_STEAL) / 100.0) * healing_mult
			
		var omni = get_total(Stat.OMNIVAMP)
		if omni > 0:
			total_heal += actual_lost * (omni / 100.0) * healing_mult

		if total_heal > 0: heal(total_heal)

		# --- RE-ROUTED ITEM HOOKS ---
		if category == "spell":
			_trigger_passive_effects("on_spell_hit", context) 
		elif category == "attack":
			# This is exactly where our Kraken item will listen and activate!
			_trigger_passive_effects("on_attack_hit_post_mitigation", context)
			
	return actual_lost

func take_damage(amount: float, type: String, source: Node, is_crit: bool = false, category: String = "spell") -> Dictionary:
	last_combat_time = Time.get_ticks_msec()
	var damage_context = { "amount": amount, "type": type, "category": category, "source": source, "is_crit": is_crit }
	_trigger_passive_effects("on_incoming_damage", damage_context)

	var final_amount = damage_context["amount"]
	var receipt: Dictionary = super.take_damage(final_amount, type, source, is_crit, category)
	
	if FLOATING_TEXT_SCENE and receipt["mitigated"] > 0:
		var text_instance = FLOATING_TEXT_SCENE.instantiate()
		get_tree().current_scene.add_child(text_instance)
		text_instance.start(receipt["mitigated"], global_position, type, is_crit)

	var post_context = { 
		"amount": receipt["mitigated"], "health_lost": receipt["health_lost"], 
		"shield_soaked": receipt["shield_soaked"], "attacker": source, 
		"type": type, "category": category
	}
	
	_trigger_passive_effects("on_take_damage", post_context)
	_trigger_passive_effects("on_hit_received_pre_mitigation", damage_context) 
	_trigger_passive_effects("on_hit_received", post_context)
	return receipt

func _roll_for_crit(base_chance: float) -> bool:
	if base_chance <= 0: return false
	var effective_chance = (base_chance / 100.0) + crit_pity_bonus
	effective_chance = min(effective_chance, 1.0)
	if randf() < effective_chance:
		crit_pity_bonus = 0.0
		return true
	else:
		crit_pity_bonus += PITY_INCREMENT
		return false

func _on_status_dealt_damage(status_id: String, receipt: Dictionary):
	var context = {"status_id": status_id, "receipt": receipt}
	_trigger_passive_effects("on_status_tick_damage", context)


# ==========================================
# 4. MOVEMENT & DASHING
# ==========================================
func dash_to_position(target_pos: Vector2, dash_speed: float, _duration: float, arrival_effects: Array = [], context: Dictionary = {}):
	nav_target = null
	current_target = null
	velocity = Vector2.ZERO
	
	dash_direction = global_position.direction_to(target_pos)
	dash_distance_remaining = global_position.distance_to(target_pos)
	
	if dash_direction == Vector2.ZERO: dash_direction = Vector2.RIGHT 

	# Ghost Mode & World Border
	if context.get("ignores_walls", false):
		collision_mask = 512 # ONLY collide with Layer 8
	else:
		collision_mask = 1 + 512 # Collide with Layer 1 AND Layer 8
	set_collision_layer_value(2, false)
	is_dashing = true
	current_dash_speed = dash_speed
	dash_arrival_effects = arrival_effects
	dash_context = context

func _process_dash(delta: float):
	var step_distance = current_dash_speed * delta
	
	if dash_distance_remaining <= step_distance:
		step_distance = dash_distance_remaining
		var final_step_vector = dash_direction * step_distance
		
		move_and_collide(final_step_vector)
		_on_dash_complete(dash_arrival_effects, dash_context)
		return

	dash_distance_remaining -= step_distance
	var step_vector = dash_direction * step_distance
	var collision = move_and_collide(step_vector)
	
	if collision:
		DevMenu.add_log("Dash abruptly stopped! Hit: %s" % collision.get_collider().name)
		_on_dash_complete(dash_arrival_effects, dash_context)

func _on_dash_complete(arrival_effects: Array, context: Dictionary):
	is_dashing = false
	velocity = Vector2.ZERO
	collision_mask = default_collision_mask
	set_collision_layer_value(2, true)
	for effect in arrival_effects:
		if effect is SkillEffect:
			effect.on_execute(self, self.level, context, null)

func stop_movement():
	if is_dashing and not can_cancel_dash:
		return
		
	if dash_tween and dash_tween.is_running():
		dash_tween.kill() 
		
	if is_dashing:
		for effect in dash_arrival_effects:
			if effect is SkillEffect:
				effect.on_execute(self, self.level, dash_context, null)

	is_dashing = false
	set_collision_layer_value(2, true)
	velocity = Vector2.ZERO
	collision_mask = default_collision_mask


# ==========================================
# 5. STATS, PASSIVES & INVENTORY OVERRIDES
# ==========================================
func recalculate_stats():
	super.recalculate_stats()
	if active_passive and active_passive.has_method("apply_stat_bonuses"):
		active_passive.apply_stat_bonuses(self)
	_refresh_ui_display()
	stats_recalculated.emit(self)

func _on_inventory_updated():
	var old_max_hp = get_total(Stat.HP)
	var old_max_res = _get_max_resource()

	for key in bonus_stats.keys():
		bonus_stats[key] = 0.0

	bonus_stats["attack_speed"] += accumulated_as_growth
		
	if inventory:
		for item in inventory.items:
			if item: 
				for stat_key in item.stats:
					if bonus_stats.has(stat_key):
						bonus_stats[stat_key] += item.stats[stat_key]
						
	var new_max_hp = get_total(Stat.HP)
	var hp_diff = new_max_hp - old_max_hp
	if hp_diff > 0:
		current_health += hp_diff
		
	if resource_type != ResourceType.NONE:
		var new_max_res = _get_max_resource()
		var res_diff = new_max_res - old_max_res
		if res_diff > 0:
			current_resource += res_diff
			
	recalculate_stats()

func update_passives(delta: float):
	if attack_cooldown_timer > 0: attack_cooldown_timer -= delta
	handle_gold_generation(delta)
	handle_regeneration(delta)

func _trigger_passive_effects(trigger_name: String, context: Dictionary = {}):
	super._trigger_passive_effects(trigger_name, context) 
	
	if active_passive and active_passive.has_method("on_combat_event"):
		active_passive.on_combat_event(trigger_name, context, self)

func _get_max_resource() -> float:
	match resource_type:
		ResourceType.MANA: return get_total(Stat.MANA)
		ResourceType.ENERGY: return get_total(Stat.ENERGY)
		ResourceType.FURY: return 100.0 
		_: return 0.0 


# ==========================================
# 6. HEALTH & RESOURCE MANAGEMENT
# ==========================================
func handle_regeneration(delta):
	if is_dead: return
	
	var max_hp = get_total(Stat.HP)
	var hp5 = get_total(Stat.HP5)
	
	if current_health < max_hp and current_health > 0:
		current_health += (hp5 / 5.0) * delta
		current_health = min(current_health, max_hp)
	elif current_health < 10:
		current_health = 0
	else: 
		current_health = max_hp
		
	if resource_type == ResourceType.NONE: return 
	
	var max_res = _get_max_resource()
	var res_regen = get_total(Stat.MANARG) 
	
	if current_resource < max_res:
		current_resource += (res_regen / 5.0) * delta 
		current_resource = min(current_resource, max_res)
	else:
		current_resource = max_res

func heal(amount: float, source: Node2D = null):
	if is_dead: return
	amount = max(0, amount)
	if has_status("grevious_wounds"): amount *= 0.6 
	var context = {"amount": amount, "source": source}
	_trigger_passive_effects("on_heal", context)
	
	var final_heal_amount = context["amount"]
	current_health += final_heal_amount
	var max_hp = get_total(Stat.HP)
	if current_health > max_hp: current_health = max_hp
	
	if amount > 5.0 and FLOATING_TEXT_SCENE and current_health < max_hp: 
		var text_instance = FLOATING_TEXT_SCENE.instantiate()
		get_tree().current_scene.add_child(text_instance)
		text_instance.start(amount, global_position, "heal", false)

func restore(resource_amt: float, health_amt: float):
	if is_dead: return
	resource_amt = max(0, resource_amt)
	health_amt = max(0, health_amt)
	
	current_health += health_amt
	var max_hp = get_total(Stat.HP)
	if current_health > max_hp: current_health = max_hp
	
	if resource_type != ResourceType.NONE:
		current_resource += resource_amt
		var max_res = _get_max_resource()
		if current_resource > max_res: current_resource = max_res


# ==========================================
# 7. PROGRESSION & ECONOMY
# ==========================================
func level_up():
	level += 1
	experience -= experience_to_next_level
	experience_to_next_level *= 1.15 
	
	base_stats["health"] = base_stats.get("health", 0.0) + hp_growth
	base_stats["Mana"] = base_stats.get("Mana", 0.0) + mana_growth
	base_stats["attack_damage"] = base_stats.get("attack_damage", 0.0) + ad_growth
	base_stats["armor"] = base_stats.get("armor", 0.0) + armor_growth
	base_stats["magic_res"] = base_stats.get("magic_res", 0.0) + mr_growth
	
	accumulated_as_growth += (as_growth_percent / 100.0)
	
	current_health += hp_growth
	current_resource += mana_growth
	
	_trigger_passive_effects("on_level_up", { "new_level": level })
	_on_inventory_updated() 
	level_updated.emit(level)
	DevMenu.add_log("%s leveled up to %s!"% [name, level])

func gain_experience(amount: float):
	experience += amount
	if experience >= experience_to_next_level: level_up()
	if FLOATING_TEXT_SCENE:
		var text = FLOATING_TEXT_SCENE.instantiate()
		get_tree().current_scene.add_child(text)
		text.start(amount, global_position, "exp", false)

func handle_gold_generation(delta):
	if gold < 20000.0: gold += get_total(Stat.GOLD_GEN) * delta

func add_gold(amount: int):
	gold += amount
	if FLOATING_TEXT_SCENE:
		var text = FLOATING_TEXT_SCENE.instantiate()
		get_tree().current_scene.add_child(text)
		text.start(amount, global_position, "gold", false)


# ==========================================
# 8. UTILITIES & UI
# ==========================================
func get_nearby_enemies(radius: float) -> Array:
	var enemies = []
	var space = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	
	var circle = CircleShape2D.new()
	circle.radius = radius
	
	query.shape = circle
	query.transform = global_transform
	query.collision_mask = 4 
	query.collide_with_areas = true
	
	var results = space.intersect_shape(query)
	for result in results:
		var unit = result.collider
		if unit is Area2D: unit = unit.get_parent()
		
		if unit is Unit and unit.team != self.team and not unit.is_dead:
			enemies.append(unit)
	return enemies

func get_current_move_speed() -> float: 
	return get_total(Stat.MS) 

func is_ranged() -> bool: 
	return get_total(Stat.RANGE) > 300.0

func die(_killer = null): 
	super.die(_killer)
	queue_free()

func record_status_damage(status_id: String, receipt: Dictionary):
	status_damage_dealt.emit(status_id, receipt)

func _refresh_ui_display():
	var ui_text = "[center][b]STATS[/b][/center]\n"
	
	for s in Stat.values():
		if not STAT_MAP.has(s): continue
		var total = get_total(s)
		if is_zero_approx(total): continue
		
		var key = STAT_MAP[s]
		var base_val = base_stats.get(key, 0.0)
		var stored_bonus = bonus_stats.get(key, 0.0)
		var value_from_items = stored_bonus
		
		if key.to_lower() == "health_regen" or key.to_lower() == "mana_regen":
			value_from_items = base_val * (stored_bonus / 100.0)
			 
		var temp_val = total - (base_val + value_from_items)
		
		# GET COLOR AND ICON
		var stat_color = StatStyle.get_color(key)
		var stat_icon = StatStyle.get_icon_tag(key, 18) 
		
		# Format: [Icon] Name: 100.00
		var line = "%s[color=%s]%s:[/color] %.2f" % [stat_icon, stat_color, key.capitalize(), total]
		
		if abs(value_from_items) > 0.01:
			var color = "green" if value_from_items > 0 else "red"
			line += " [color=%s](%+.2f)[/color]" % [color, value_from_items]
			
		if abs(temp_val) > 0.01:
			var color = "cornflower_blue" if temp_val > 0 else "red"
			line += " [color=%s](%+.2f)[/color]" % [color, temp_val]
			
		ui_text += line + "\n"
		
	stats_updated.emit(ui_text)



func load_saved_level(saved_level: int, saved_exp: float):
	# Reset to Level 1
	level = 1
	experience = 0.0
	experience_to_next_level = 280.0
	accumulated_as_growth = 0.0
	
	# Reload fresh Level 1 base stats from the resource
	if current_champion_data:
		base_stats[STAT_MAP[Stat.HP]] = current_champion_data.base_hp
		base_stats[STAT_MAP[Stat.MANA]] = current_champion_data.base_resource
		base_stats[STAT_MAP[Stat.AD]] = current_champion_data.base_ad
		base_stats[STAT_MAP[Stat.AR]] = current_champion_data.base_armor
		base_stats[STAT_MAP[Stat.MR]] = current_champion_data.base_mr
	
	# Simulate level ups to catch up to the saved level!
	while level < saved_level:
		level += 1
		experience_to_next_level *= 1.15
		
		base_stats["health"] = base_stats.get("health", 0.0) + hp_growth
		base_stats["Mana"] = base_stats.get("Mana", 0.0) + mana_growth
		base_stats["attack_damage"] = base_stats.get("attack_damage", 0.0) + ad_growth
		base_stats["armor"] = base_stats.get("armor", 0.0) + armor_growth
		base_stats["magic_res"] = base_stats.get("magic_res", 0.0) + mr_growth
		
		accumulated_as_growth += (as_growth_percent / 100.0)
	
	# Set the leftover experience
	experience = saved_exp
	level_updated.emit(level)
