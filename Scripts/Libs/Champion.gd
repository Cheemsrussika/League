extends Unit
class_name Champion

# --- ENUMS ---
enum ResourceType { MANA, ENERGY, FURY, NONE }

# --- CONFIGURATION ---
@export_group("Champion Identity")
@export var resource_type: ResourceType = ResourceType.MANA

@export_group("Leveling Stats (Growth)")
@export var hp_growth: float = 80.0
@export var mana_growth: float = 40.0
@export var ad_growth: float = 3.5
@export var armor_growth: float = 3.0
@export var mr_growth: float = 1.25
@export var as_growth_percent: float = 2.0 

# --- STATE ---
var level: int = 1
var experience: float = 0.0
var experience_to_next_level: float = 280.0
var accumulated_as_growth: float = 0.0 

# --- SIGNALS ---
signal gold_updated(amount: float)
signal level_updated(new_level: int)
signal status_damage_dealt(status_id: String, receipt: Dictionary)
signal stats_recalculated(unit: Unit)

# --- COMPONENTS ---
@onready var attack_range_area: Area2D = $AttackRange

func _process(delta: float) -> void:
	_handle_shields(delta)
	handle_regeneration(delta) # Handles HP and Resource
	
	# 2. Run Champion Logic
	if attack_cooldown_timer > 0: 
		attack_cooldown_timer -= delta
		
	handle_gold_generation(delta)

# --- CHAMPION VARS ---
var current_resource: float = 0.0
var gold: float = 10000.0:
	set(value):
		gold = value
		gold_updated.emit(gold)

# --- COMBAT CONTROL ---
var is_winding_up: bool = false
var windup_timer: float = 0.0
const WINDUP_PERCENT: float = 0.3

# --- CRIT SYSTEM ---
var crit_pity_bonus: float = 0.0
const PITY_INCREMENT: float = 0.05

# --- RESOURCE HELPER ---
func _get_max_resource() -> float:
	match resource_type:
		ResourceType.MANA: return get_total(Stat.MANA)
		ResourceType.ENERGY: return get_total(Stat.ENERGY)
		ResourceType.FURY: return 100.0 # Example cap for Fury
		_: return 0.0 # NONE

# --- LIFECYCLE ---
func _ready():
	super._ready()
	unit_type = UnitType.CHAMPION 
	inventory = $InventoryComponent
	
	# Initialize Resource Based on Enum
	match resource_type:
		ResourceType.MANA: current_resource = base_stats.get("Mana", 0.0)
		ResourceType.ENERGY: current_resource = base_stats.get("Energy", 0.0)
		ResourceType.FURY: current_resource = 0.0 # Fury usually starts empty
		ResourceType.NONE: current_resource = 0.0
		
	if inventory:
		inventory.inventory_changed.connect(_on_inventory_updated)
		_on_inventory_updated()

# --- COMBAT & MOVEMENT LOGIC ---
func execute_combat_logic(delta: float):
	if is_winding_up:
		velocity = Vector2.ZERO
		windup_timer -= delta
		if windup_timer <= 0:
			_complete_attack()
		return 
		
	if is_instance_valid(current_target):
		var dist = global_position.distance_to(current_target.global_position)
		var range_stat = get_total(Stat.RANGE) + 35.0
		
		if dist <= range_stat:
			velocity = Vector2.ZERO
			if attack_cooldown_timer <= 0:
				_start_windup(current_target)
		else:
			var move_spd = get_current_move_speed()
			velocity = global_position.direction_to(current_target.global_position) * move_spd
			
	elif nav_target != null:
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

# --- ATTACK SEQUENCE ---
func _start_windup(target: Node2D):
	is_winding_up = true
	var aps = max(0.01, get_total(Stat.AS))
	var total_attack_time = 1.0 / aps
	windup_timer = total_attack_time * WINDUP_PERCENT

func _complete_attack():
	is_winding_up = false 
	if is_instance_valid(current_target):
		var dist = global_position.distance_to(current_target.global_position)
		if dist <= get_total(Stat.RANGE) + 50.0:
			perform_auto_attack_hit(current_target)
		else:
			print("Missed! Target moved out of range.")
	
	var aps = max(0.01, get_total(Stat.AS))
	var total_time = 1.0 / aps
	attack_cooldown_timer = total_time - (total_time * WINDUP_PERCENT)

# --- SPELLCASTING ---
func on_skill_cast(ability_identifier: String, mana_cost: float = 0.0, is_toggle: bool = false):
	var context = {
		"ability_id": ability_identifier, "mana_cost": mana_cost,
		"is_toggle": is_toggle, "cast_time": Time.get_ticks_msec()
	}
	_trigger_passive_effects("on_ability_activated", context)

func apply_physical_spell_hit(target: Node2D, base_damage: float, scaling_ratio: float = 1.0, can_crit: bool = false, crit_mod: float = 1.0):
	if not is_instance_valid(target) or target.is_queued_for_deletion(): return
	if "team" in target and target.team == team: return

	var total_ad = get_total(Stat.AD)
	var raw_damage = base_damage + (total_ad * scaling_ratio)
	
	var is_crit = false
	if can_crit:
		is_crit = _roll_for_crit(get_total(Stat.CRIT))
		if is_crit:
			raw_damage *= (get_total(Stat.CRIT_DMG) * crit_mod)
			
	var context = { 
		"target": target, "damage": raw_damage,
		"is_crit": is_crit, "is_spell": true, "damage_type": "physical"
	}
	
	_trigger_passive_effects("on_attack", context)
	raw_damage = context["damage"]
	var dealt = deal_damage(target, raw_damage, "physical", "spell", is_crit)

	var lifesteal = get_total(Stat.LIFE_STEAL)
	if lifesteal > 0 and dealt > 0: heal(dealt * (lifesteal / 100.0))
	return dealt

func apply_spell_damage(target: Node2D, base_damage: float, type: String, scaling_stat: Stat = Stat.AD, scaling_ratio: float = 0.0):
	if not is_instance_valid(target): return
	if "team" in target and target.team == team: return
	
	var total_damage = base_damage
	if scaling_ratio > 0.0:
		total_damage += get_total(scaling_stat) * scaling_ratio
		
	var context = { "target": target, "damage": total_damage, "type": type, "is_aoe": false }
	_trigger_passive_effects("on_spell_hit", context)
	total_damage = context["damage"]
	
	var dealt = deal_damage(target, total_damage, type, "spell", false)
	
	var omnivamp = get_total(Stat.OMNIVAMP)
	if omnivamp > 0 and dealt > 0: heal(dealt * (omnivamp / 100.0))
	return dealt

func perform_auto_attack_hit(target: Node2D):
	if not is_instance_valid(target): return
	if "team" in target and target.team == team: return
	
	var damage_buckets = { "physical": get_total(Stat.AD), "magic": 0.0, "true": 0.0 }
	
	if get_total(Stat.AP) > get_total(Stat.AD):
		damage_buckets["magic"] = get_total(Stat.AP) * 0.6
		damage_buckets["physical"] = 0.0
		
	var is_crit = _roll_for_crit(get_total(Stat.CRIT))
	if is_crit:
		var crit_mult = get_total(Stat.CRIT_DMG)
		if damage_buckets["physical"] > 0: damage_buckets["physical"] *= crit_mult
		if damage_buckets["magic"] > 0: damage_buckets["magic"] *= crit_mult
		
	var context = { "target": target, "is_crit": is_crit, "buckets": damage_buckets }
	_trigger_passive_effects("on_attack", context)
	
	var total_damage_dealt = 0.0
	var physical_damage_dealt = 0.0
	last_combat_time = Time.get_ticks_msec()

	for type in damage_buckets.keys():
		var raw_amount = damage_buckets[type]
		if raw_amount > 0:
			var health_lost = deal_damage(target, raw_amount, type, "attack", is_crit)
			total_damage_dealt += health_lost 
			if type == "physical": physical_damage_dealt += health_lost
				
	var total_heal = 0.0
	var lifesteal = get_total(Stat.LIFE_STEAL)
	if lifesteal > 0: total_heal += physical_damage_dealt * (lifesteal / 100.0)
	var omnivamp = get_total(Stat.OMNIVAMP) 
	if omnivamp > 0: total_heal += total_damage_dealt * (omnivamp / 100.0)
	if total_heal > 0 : heal(total_heal)

func deal_damage(target: Node2D, amount: float, type: String, category: String, is_crit: bool = false) -> float:
	var receipt = target.take_damage(amount, type, self, is_crit, category)
	var mitigated_amt = receipt["mitigated"] 
	var actual_lost = receipt["health_lost"]
	
	var ratio = 0.0
	if amount > 0.0: ratio = mitigated_amt / amount
		
	var report = { "type": type, "ratio": ratio, "target": target }
	_trigger_passive_effects("on_bucket_damage_landed", report)
	damage_done += mitigated_amt 
	
	if mitigated_amt > 0 and inventory:
		var context = {
			"target": target, "amount": mitigated_amt, "health_lost": actual_lost,
			"damage_type": type, "category": category, "is_crit": is_crit, "receipt": receipt      
		}
		_trigger_passive_effects("on_damage_dealt", context)
		if category == "spell": _trigger_passive_effects("on_spell_landed", context)
		elif category == "attack": _trigger_passive_effects("on_attack_landed", context)
				
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

func _on_status_dealt_damage(status_id: String, receipt: Dictionary):
	var context = {"status_id": status_id, "receipt": receipt}
	_trigger_passive_effects("on_status_tick_damage", context)

# --- REGENERATION ---
func handle_regeneration(delta):
	if is_dead: return
	
	# 1. Health Regeneration
	var max_hp = get_total(Stat.HP)
	var hp5 = get_total(Stat.HP5)
	
	if current_health < max_hp and current_health > 0:
		current_health += (hp5 / 5.0) * delta
		current_health = min(current_health, max_hp)
	elif current_health < 10:
		current_health = 0
	else: 
		current_health = max_hp
		
	# 2. Resource Regeneration
	if resource_type == ResourceType.NONE: return # No resource to regen
	
	var max_res = _get_max_resource()
	var res_regen = get_total(Stat.MANARG) # Assuming MANARG stat handles general resource regen
	
	if current_resource < max_res:
		current_resource += (res_regen / 5.0) * delta 
		current_resource = min(current_resource, max_res)
	else:
		current_resource = max_res

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

func get_nearby_enemies(radius: float) -> Array:
	var enemies = []
	var space = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	
	var circle = CircleShape2D.new()
	circle.radius = radius
	
	query.shape = circle
	query.transform = global_transform
	query.collision_mask = 4 # Ensure this matches your Unit's collision layer
	query.collide_with_areas = true
	
	var results = space.intersect_shape(query)
	for result in results:
		var unit = result.collider
		if unit is Area2D: unit = unit.get_parent()
		
		if unit is Unit and unit.team != self.team and not unit.is_dead:
			enemies.append(unit)
	return enemies

# --- INVENTORY & UI UPDATES ---
func _on_inventory_updated():
	# 1. Store old max values before recalculating
	var old_max_hp = get_total(Stat.HP)
	var old_max_res = _get_max_resource()

	# 2. Reset and sum up stats from items
	for key in bonus_stats.keys():
		bonus_stats[key] = 0.0

	bonus_stats["attack_speed"] += accumulated_as_growth
		
	if inventory:
		for item in inventory.items:
			if item: 
				for stat_key in item.stats:
					if bonus_stats.has(stat_key):
						bonus_stats[stat_key] += item.stats[stat_key]
						
	# 3. Apply Health Difference
	var new_max_hp = get_total(Stat.HP)
	var hp_diff = new_max_hp - old_max_hp
	if hp_diff > 0:
		current_health += hp_diff
		
	# 4. Apply Resource Difference safely
	if resource_type != ResourceType.NONE:
		var new_max_res = _get_max_resource()
		var res_diff = new_max_res - old_max_res
		if res_diff > 0:
			current_resource += res_diff
			
	recalculate_stats()

func recalculate_stats():
	super.recalculate_stats()
	_refresh_ui_display()
	stats_recalculated.emit(self)

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
	print(name, " leveled up to ", level, "!")

# --- UTILS ---
func get_current_move_speed() -> float: return get_total(Stat.MS) 

func _roll_for_crit(base_chance: float) -> bool:
	var effective_chance = (base_chance / 100.0) + crit_pity_bonus
	effective_chance = min(effective_chance, 1.0)
	if randf() < effective_chance:
		crit_pity_bonus = 0.0
		return true
	else:
		crit_pity_bonus += PITY_INCREMENT
		return false

func update_passives(delta: float):
	if attack_cooldown_timer > 0: attack_cooldown_timer -= delta
	handle_gold_generation(delta)
	handle_regeneration(delta)

func handle_gold_generation(delta):
	if gold < 20000.0: gold += get_total(Stat.GOLD_GEN) * delta

func add_gold(amount: int):
	gold += amount
	if FLOATING_TEXT_SCENE:
		var text = FLOATING_TEXT_SCENE.instantiate()
		get_tree().current_scene.add_child(text)
		text.start(amount, global_position, "gold", false)

func die(killer = null): unit_died.emit(self)
func is_ranged() -> bool: return get_total(Stat.RANGE) > 300.0

func _refresh_ui_display():
	var ui_text = "[b]STATS[/b]\n"
	for s in Stat.values():
		if not STAT_MAP.has(s): continue
		var total = get_total(s)
		if is_zero_approx(total): continue
		
		var key = STAT_MAP[s]
		var base_val = base_stats.get(key, 0.0)
		var stored_bonus = bonus_stats.get(key, 0.0)
		var value_from_items = stored_bonus
		
		if key == "health_regen" or key == "Mana_Regen":
			value_from_items = base_val * (stored_bonus / 100.0)
			 
		var temp_val = total - (base_val + value_from_items)
		var line = "%s: %.2f" % [key.capitalize(), total]
		
		if abs(value_from_items) > 0.01:
			var color = "green" if value_from_items > 0 else "red"
			line += " [color=%s](%+.2f)[/color]" % [color, value_from_items]
		if abs(temp_val) > 0.01:
			var color = "cornflower_blue" if temp_val > 0 else "red"
			line += " [color=%s](%+.2f)[/color]" % [color, temp_val]
		ui_text += line + "\n"
	stats_updated.emit(ui_text)
	if has_method("_update_attack_range_circle"): _update_attack_range_circle()

func _update_attack_range_circle():
	if not attack_range_area: return
	var current_range = get_total(Stat.RANGE)
	attack_range_area.scale = Vector2(current_range, current_range)
	
func record_status_damage(status_id: String, receipt: Dictionary):
	status_damage_dealt.emit(status_id, receipt)
	
func gain_experience(amount: float):
	experience += amount
	if experience >= experience_to_next_level: level_up()
	if FLOATING_TEXT_SCENE:
		var text = FLOATING_TEXT_SCENE.instantiate()
		get_tree().current_scene.add_child(text)
		text.start(amount, global_position, "exp", false)
