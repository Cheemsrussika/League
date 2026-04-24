# res://Skills/Effects/Effect_Dash.gd
extends SkillEffect
class_name Effect_Dash

enum DashType { DIRECTIONAL, TARGET_ENEMY, TARGET_ALLY }
@export var effect_on_arrival: Array[SkillEffect]
@export var effect_on_start: Array[SkillEffect]
@export var type: DashType = DashType.DIRECTIONAL
@export var speed: float = 1200.0
@export var fixed_duration: float = 0.2
@export var stop_at_target: bool = true

func on_execute(caster: Node2D, _level: int, target_data: Dictionary, _ref: Resource) -> void:
	var target_pos = Vector2.ZERO
	var target_node = target_data.get("target") # For targeted dashes

	match type:
		DashType.DIRECTIONAL:
			# Skillshot dash (like Lucian E)
			target_pos = target_data.get("target_position", caster.get_global_mouse_position())
			
		DashType.TARGET_ENEMY:
			# Like Jax Q or Yasuo E
			if is_instance_valid(target_node) and target_node.team != caster.team:
				target_pos = target_node.global_position
			else: return # Invalid target
			
		DashType.TARGET_ALLY:
			# Like Lee Sin W or Braum W
			if is_instance_valid(target_node) and target_node.team == caster.team:
				target_pos = target_node.global_position
			else: return # Invalid target
	
	# Execute the dash
	if caster.has_method("dash_to_position"):
		if not effect_on_start.is_empty():
			for effect in effect_on_start:
				if effect: 
					effect.on_execute(caster, _level, target_data, _ref)
		caster.dash_to_position(target_pos, speed, fixed_duration)
		# Check if the array has any effects inside
		if not effect_on_arrival.is_empty():
			for effect in effect_on_arrival:
				if effect: # Safety check to ensure the slot isn't null
					effect.on_execute(caster, _level, target_data, _ref)
