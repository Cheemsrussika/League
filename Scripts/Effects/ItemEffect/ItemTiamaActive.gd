extends ItemEffect
class_name TiamatEffect

@export_group("Active: Crescent")
@export var active_base_damage: float = 40.0
# --- NEW: Use an Array of your custom LEGO scaling blocks ---
@export var active_scaling_factors: Array[ScalingFactor] = [] 
@export var active_radius: float = 150.0
@export var active_vfx_scene: PackedScene 

@export_group("Passive: Cleave")
# --- NEW: Use an Array of your custom LEGO scaling blocks ---
@export var passive_scaling_factors: Array[ScalingFactor] = [] 
@export var passive_radius: float = 100.0
@export var passive_vfx_scene: PackedScene 
var active_damage = active_base_damage
var damage_dealt=0.0
func _init():
	is_unique = true
	id = "tiamat_cleave"
	cooldown = 10.0 

func on_active_use(owner_node: Node) -> void:
	
	
	# --- Loop through your ScalingFactors for the Active ---
	for factor in active_scaling_factors:
		active_damage += factor.calculate_value(owner_node)
	
	# Spawn VFX for the Active
	if active_vfx_scene:
		var vfx = active_vfx_scene.instantiate()
		owner_node.add_child(vfx)
		vfx.global_position = owner_node.global_position
	_apply_splash(owner_node, owner_node.global_position, active_damage, active_radius, null)
	if active_damage>active_base_damage:
		active_damage = active_damage/5
		if active_damage<active_base_damage:
			active_damage=active_base_damage
# --- CHANGED: Renamed to on_attack to match your Effect_Damage.gd trigger! ---
func on_attack(owner_node: Node, context: Dictionary) -> void:
	if not context.has("target"): return
	var primary_target = context["target"]
	
	var total_damage = active_base_damage
	
	# --- Loop through your ScalingFactors for the Passive ---
	for factor in passive_scaling_factors:
		total_damage += factor.calculate_value(owner_node, primary_target)
		
	# --- NEW: Apply the on_hit_multiplier from your Skill Context! ---
	# This means if a skill has a 50% on_hit_multiplier, the Tiamat splash does 50% damage
	var multiplier = context.get("on_hit_mult", 1.0)
	total_damage *= multiplier
		
	# Spawn VFX for the Passive
	if passive_vfx_scene:
		var vfx = passive_vfx_scene.instantiate()
		owner_node.get_tree().current_scene.add_child(vfx)
		vfx.global_position = primary_target.global_position
	active_damage+= (0.1*total_damage)

	_apply_splash(owner_node, primary_target.global_position, total_damage, passive_radius, primary_target)

# ==========================================
# 3. UNIFIED SPLASH LOGIC
# ==========================================
func _apply_splash(owner_node: Node, origin_pos: Vector2, damage_amount: float, radius: float, ignore_target: Node) -> void:
	# Grab from your global 'unit' group instead
	var all_units = owner_node.get_tree().get_nodes_in_group("unit")
	
	for unit in all_units:
		if not is_instance_valid(unit) or unit.get("is_dead"): 
			continue
			
		# 1. Skip the owner of the Tiamat! (Don't splash ourselves)
		if unit == owner_node: 
			continue
			
		# 2. --- NEW: Dynamic Team Checking ---
		# Only hit units that are on a DIFFERENT team.
		if owner_node.get("team") != null and unit.get("team") != null:
			if owner_node.team == unit.team:
				continue # Skip allies!
		
		# 3. Skip the primary target we already hit with the main attack
		if unit == ignore_target: 
			continue 
		
		# 4. Distance and Damage Check
# 4. Distance and Damage Check
		var distance = origin_pos.distance_to(unit.global_position)
		if distance <= radius:
			if unit.has_method("take_damage"):
				# FIX: Catch the Dictionary receipt first!
				var receipt = unit.take_damage(damage_amount, "physical", owner_node, false, "item")
				
				# Extract the actual damage dealt and add it to your tracker
				damage_dealt += receipt.get("health_lost", 0.0)
func get_tooltip_extra() -> String:
	var text=""
	text+= str("\nDamage dealt:%.1f\n"%[damage_dealt])
	text+= str("Damage Aculmulated:%.1f\n"%[active_damage])
	return text
