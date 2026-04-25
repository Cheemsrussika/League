# res://Skills/Effects/Effect_Dash.gd
extends SkillEffect
class_name Effect_Dash

enum DashType { DIRECTIONAL, TARGET_ENEMY, TARGET_ALLY }

@export_group("Dash Range")
## Minimum distance the dash will travel, even if mouse is close.
@export var min_range: float = 100.0
## Maximum distance the dash will travel.
@export var max_range: float = 450.0

@export_group("Settings")
@export var type: DashType = DashType.DIRECTIONAL
@export var speed: float = 1200.0
@export var is_cancelable: bool = true

@export_group("Effects")
@export var effect_on_start: Array[SkillEffect]
@export var effect_on_arrival: Array[SkillEffect]

func on_execute(caster: Node2D, _level: int, target_data: Dictionary, _ref: Resource) -> void:
	var mouse_pos = target_data.get("target_position", caster.get_global_mouse_position())
	var target_pos = Vector2.ZERO
	
	# 1. Calculate the raw vector from caster to mouse
	var diff = mouse_pos - caster.global_position
	var distance_to_mouse = diff.length()
	var direction = diff.normalized()

	# 2. Determine final dash distance based on Mouse vs Min/Max
	# If Dash is TARGETED, we go to the unit. If DIRECTIONAL, we use the mouse logic.
	if type == DashType.DIRECTIONAL:
		var final_dist = clamp(distance_to_mouse, min_range, max_range)
		target_pos = caster.global_position + (direction * final_dist)
	else:
		# Targeted Logic (Enemy/Ally)
		var target_node = target_data.get("target_unit")
		if is_instance_valid(target_node):
			target_pos = target_node.global_position
		else:
			return # No unit found for targeted dash

	# 3. Execute in Champion
	if caster.has_method("dash_to_position"):
		caster.set("can_cancel_dash", is_cancelable)
		
		# Start Effects
		for effect in effect_on_start:
			if effect: effect.on_execute(caster, _level, target_data, _ref)
		
		# IMPORTANT: We pass '0' for fixed_duration because the 
		# Champion script will calculate Time = Dist / Speed
		caster.dash_to_position(target_pos, speed, 0.0, effect_on_arrival, target_data)
