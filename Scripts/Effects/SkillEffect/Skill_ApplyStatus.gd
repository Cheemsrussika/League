# res://Skills/Effects/Effect_ApplyStatus.gd
extends SkillEffect
class_name Effect_ApplyStatus

@export var status_id: String = ""
@export var duration: float = 3.0
@export var power_per_level: Array[float] = [10.0, 20.0, 30.0]

@export_group("Data Injection")
## Put any extra variables the Status needs here (e.g. "silence_duration": 1.5)
@export var extra_data: Dictionary = {}
# Inside Effect_ApplyStatus.gd

@export var scaling_factors: Array[ScalingFactor] = []

func on_execute(caster: Node2D, skill_level: int, target_data: Dictionary, _ref: Resource) -> void:
	var target = target_data.get("target_unit")
	if target == null:
		target = caster
	
	if target and target.has_method("apply_status_effect"):
		var lvl_idx = clamp(skill_level - 1, 0, power_per_level.size() - 1)
		var base_power = power_per_level[lvl_idx]
		
		# 1. Apply the Status
		target.apply_status_effect(status_id, duration, 1, base_power, caster)
		
		# 2. Get the node and inject the LEGOs
		var status_node = target.get_node_or_null("StatusContainer/" + status_id)
		if status_node:
			# Pass the base damage
			if "bonus_damage_base" in status_node:
				status_node.bonus_damage_base = base_power
			
			# Pass the SCALING RESOURCES themselves (for real-time math)
			if "scaling_factors" in status_node:
				status_node.scaling_factors = scaling_factors
				
			# Pass anything else from the extra_data dictionary
			for key in extra_data:
				if key in status_node:
					status_node.set(key, extra_data[key])
