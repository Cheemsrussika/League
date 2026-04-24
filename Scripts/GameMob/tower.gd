extends Unit
class_name Tower

# --- CONFIG ---
@export_group("Stats")
@export var attack_range: float = 800.0
@export var projectile_scene: PackedScene
@export_group("Tower Plating")
@export var plating_count: int = 5
@export var armor_per_plate: float = 35.0
@export var mr_per_plate: float = 35.0
@export var gold_per_plate: int = 125

@export_group("Ramping Damage (Heat)")
@export var heat_damage_increase: float = 0.40 
@export var max_heat_stacks: int = 3           
var current_heat_stacks: int = 0
var last_attacked_unit: Unit = null

# --- REFS ---
var targets_in_range: Array[Unit] = []
@onready var range_area: Area2D = $RangeArea 
@onready var color_rect: ColorRect = $HealthRootControl/ColorRect
@onready var health_bar: ProgressBar = $HealthRootControl/Health

# --- STATE ---
var next_priority_target: Unit = null 
var plates_lost: int = 0
var champion_damage_ledger: Dictionary = {} 
var assist_timeout: float = 10.0 
func _ready():
	super._ready()
	unit_type = UnitType.TOWER
	base_stats["attack_range"]=attack_range
	var current_range = get_total(Stat.RANGE)
	range_area.scale = Vector2(current_range, current_range)
	current_health=get_total(Stat.HP)
	health_bar.max_value=current_health
	health_bar.value=current_health
	if range_area:
		range_area.body_entered.connect(_on_body_entered)
		range_area.body_exited.connect(_on_body_exited)
	
	
	if color_rect and color_rect.material:
		color_rect.material.set_shader_parameter("plates", plating_count)
	if GameEvents:
		GameEvents.unit_damaged.connect(_on_unit_damaged)
	
	recalculate_stats()
func _on_body_entered(body: Node2D):
	# When an enemy walks in, add them to the END of the line
	if body is Unit and not body.is_dead and body.team != team and body.team != 0:
		if not targets_in_range.has(body):
			targets_in_range.append(body)

func _on_body_exited(body: Node2D):
	# When an enemy walks out, remove them from the line
	if targets_in_range.has(body):
		targets_in_range.erase(body)
func _update_shader():
	if health_bar and health_bar.material:
		var health_ratio = current_health / get_total(Stat.HP)
		
		# Set the parameters in the shader
		health_bar.material.set_shader_parameter("health", health_ratio)
		health_bar.material.set_shader_parameter("plates_broken", plates_lost)
func _process(delta: float):
	if is_dead: return
	var champs_in_ledger = champion_damage_ledger.keys()
	for champ in champs_in_ledger:
		champion_damage_ledger[champ] -= delta
		if champion_damage_ledger[champ] <= 0 or not is_instance_valid(champ) or champ.is_dead:
			champion_damage_ledger.erase(champ)
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	
	_update_target_logic()
	
	if attack_cooldown_timer <= 0 and is_instance_valid(current_target):
		_attack()

# --- PLATING LOGIC ---

func _check_plating_break(context:Dictionary):
	var killer = context.get("source")
	var max_hp = get_total(Stat.HP)
	var health_per_plate = max_hp / plating_count
	var expected_plates_lost = floor((max_hp - current_health) / health_per_plate)
	_update_shader()
	if expected_plates_lost > plates_lost:
		var plates_to_break = expected_plates_lost - plates_lost
		plates_lost = expected_plates_lost
		plate_broke(killer)
		bonus_stats["armor"] += armor_per_plate * plates_to_break
		bonus_stats["magic_res"] += mr_per_plate * plates_to_break
		print("Plate broken! Tower gained resistance. Current Armor: ", get_total(Stat.AR))
		recalculate_stats()

# --- COMBAT ---
func plate_broke(killer: Unit = null):
	var eligible_champions = champion_damage_ledger.keys()
	if eligible_champions.size() > 0:
		var split_gold = float(gold_per_plate) / eligible_champions.size()
		for champ in eligible_champions:
			if champ.has_method("add_gold"):
				champ.add_gold(split_gold)
				print(champ.name, " received ", split_gold, " plate gold!")
	else:
		print("Plate broke, but no champions were around to claim the gold.")

func _attack():
	if not projectile_scene or not is_instance_valid(current_target): return
	
	var base_damage = get_total(Stat.AD)
	var final_damage = base_damage
	
	if current_target.unit_type == UnitType.CHAMPION:
		if current_target == last_attacked_unit:
			current_heat_stacks = min(current_heat_stacks + 1, max_heat_stacks)
		else:
			current_heat_stacks = 0
			last_attacked_unit = current_target
			
		final_damage *= (1.0 + (current_heat_stacks * heat_damage_increase))
	else:
		current_heat_stacks = 0
		last_attacked_unit = current_target

	# Launch Projectile
	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + Vector2(0, -50)
	
	var context = {"target": current_target, "damage": final_damage}
	_trigger_passive_effects("on_attack",{"target":current_target})
	final_damage = context["damage"]

	projectile.launch(current_target, final_damage, self, current_heat_stacks)
	
	var aps = max(0.1, get_total(Stat.AS))
	attack_cooldown_timer = 1.0 / aps

func take_damage(amount: float, type: String, source: Node, is_crit: bool = false, category: String = "attack") -> Dictionary:
	var context = {"amount": amount, "type": type, "source": source}
	_trigger_passive_effects("on_incoming_damage", context)
	
	# --- 1. BACKDOOR PROTECTION CHECK ---
	var has_enemy_minions = false
	for unit in targets_in_range:
		if is_instance_valid(unit) and not unit.is_dead and unit.unit_type == UnitType.MINION:
			has_enemy_minions = true
			break
			
	if not has_enemy_minions:
		context["amount"] /= 3.0 
	if source and source.unit_type == UnitType.CHAMPION:
		champion_damage_ledger[source] = assist_timeout
	var receipt = super.take_damage(context["amount"], type, source, is_crit, category)
	if FLOATING_TEXT_SCENE and receipt["health_lost"] > 0:
		var text_instance = FLOATING_TEXT_SCENE.instantiate()
		get_tree().current_scene.add_child(text_instance)
		# Position it slightly above the tower's head
		var text_pos = global_position + Vector2(0, -100)
		text_instance.start(receipt["health_lost"], text_pos, type, is_crit)
		
	_check_plating_break(context)
	if health_bar: 
		health_bar.value = current_health
		
	return receipt



# --- TARGETING LOGIC ---

func _update_target_logic():
	var old_target = current_target
	

	targets_in_range = targets_in_range.filter(func(t): return is_instance_valid(t) and not t.is_dead)
	if is_instance_valid(next_priority_target):
		if targets_in_range.has(next_priority_target):
			current_target = next_priority_target
		else:
			next_priority_target = null 
	if is_instance_valid(current_target):
		if not targets_in_range.has(current_target):
			current_target = null
	else:
		current_target = null
	if current_target == null and targets_in_range.size() > 0:
		current_target = _get_first_in_line()
	if current_target == null or current_target != old_target:
		current_heat_stacks = 0
		last_attacked_unit = null

func _get_first_in_line() -> Unit:
	var valid_minions = []
	
	# Gather all minions in range
	for unit in targets_in_range:
		if unit.unit_type == UnitType.MINION:
			valid_minions.append(unit)
			

	if valid_minions.size() > 0:
		valid_minions.sort_custom(func(a, b):
			return a.minion_role > b.minion_role
		)
		return valid_minions[0]
	for unit in targets_in_range:
		if unit.unit_type == UnitType.CHAMPION:
			return unit
	return targets_in_range[0]

func _find_best_target() -> Unit:
	if not range_area: return null

	var potential_targets = range_area.get_overlapping_bodies()
	var minions = []
	var champions = []
	
	for body in potential_targets:

		if body is Unit and not body.is_dead and body.team != team and body.team != 0:
			if body.unit_type == UnitType.MINION:
				minions.append(body)
			elif body.unit_type == UnitType.CHAMPION:
				champions.append(body)

	if minions.size() > 0:
		return _get_closest(minions)
	# Priority 2: Nearest Champion
	if champions.size() > 0:
		return _get_closest(champions)
		
	return null

# --- TARGETING HELPERS ---

func _is_in_range(unit: Unit) -> bool:
	if not is_instance_valid(unit): return false
	return global_position.distance_to(unit.global_position) <= attack_range

func _get_closest(units: Array) -> Unit:
	var closest = units[0]
	var min_dist = global_position.distance_to(closest.global_position)
	for i in range(1, units.size()):
		var dist = global_position.distance_to(units[i].global_position)
		if dist < min_dist:
			min_dist = dist
			closest = units[i]
	return closest
	
# --- SIGNAL HANDLERS ---

func _on_unit_damaged(victim: Unit, attacker: Unit, _amount: float):
	if not is_instance_valid(victim) or not is_instance_valid(attacker): 
		return
	if victim.team == self.team and victim.unit_type == UnitType.CHAMPION:
		if attacker.team != self.team and attacker.unit_type == UnitType.CHAMPION:
			if targets_in_range.has(attacker):
				print("TOWER AGGRO TRIGGERED ON: ", attacker.name)
				next_priority_target = attacker
