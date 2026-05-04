extends SkillEffect
class_name Effect_Dash

enum DashType { DIRECTIONAL, TARGET_ENEMY, TARGET_ALLY }

@export_group("Dash Range")
@export var min_range: float = 100.0
@export var max_range: float = 450.0
@export var is_fixed_distance: bool = false 

@export_group("Settings")
@export var type: DashType = DashType.DIRECTIONAL
@export var speed: float = 1200.0
@export var is_cancelable: bool = true
@export var ignores_walls: bool = false 

@export_group("Effects")
@export var effect_on_start: Array[SkillEffect]
@export var effect_on_arrival: Array[SkillEffect]

func on_execute(caster: Node2D, _level: int, target_data: Dictionary, _ref: Resource) -> void:
	var mouse_pos = target_data.get("target_position", caster.get_global_mouse_position())
	var target_pos = Vector2.ZERO
	
	var diff = mouse_pos - caster.global_position
	var distance_to_mouse = diff.length()
	var direction = diff.normalized()

	if type == DashType.DIRECTIONAL:
		# --- FIXED DISTANCE LOGIC ---
		var final_dist = max_range if is_fixed_distance else clamp(distance_to_mouse, min_range, max_range)
		target_pos = caster.global_position + (direction * final_dist)
		
	else:
		var target_node = target_data.get("target_unit")
		if is_instance_valid(target_node):
			# --- NEW: Calculate "Dash Through" distance here! ---
			var dist_to_enemy = caster.global_position.distance_to(target_node.global_position)
			var dir_to_enemy = caster.global_position.direction_to(target_node.global_position)
			
			# Make this big enough to clear BOTH character's hitboxes!
			var dash_offset = 150.0 
			
			# Limit total distance so you don't dash infinitely if the enemy is far away
			var total_dist = min(dist_to_enemy + dash_offset, max_range)
			target_pos = caster.global_position + (dir_to_enemy * total_dist)
		else:
			return 

	if caster.has_method("dash_to_position"):
		caster.set("can_cancel_dash", is_cancelable)
		
		for effect in effect_on_start:
			if effect: effect.on_execute(caster, _level, target_data, _ref)
		
		target_data["ignores_walls"] = ignores_walls 
		
		caster.dash_to_position(target_pos, speed, 0.0, effect_on_arrival, target_data)
