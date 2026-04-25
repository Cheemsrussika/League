# res://Skills/Effects/Effect_ApplyStats.gd
extends SkillEffect
class_name Effect_ApplyStats

@export_group("Stat Mapping")
@export var target_stat: Unit.Stat = Unit.Stat.MS # We brought this back!
@export var status_id: String = ""
@export var duration: float = 3.0
@export var power_per_level: Array[float] = [10.0, 20.0, 30.0]

@export_group("Scaling")
@export var scaling_factors: Array[ScalingFactor] = []

@export_group("Data Injection")
@export var extra_data: Dictionary = {}

func on_execute(caster: Node2D, skill_level: int, target_data: Dictionary, _ref: Resource) -> void:
	var target = target_data.get("target_unit")
	if target == null:
		target = caster
	
	if target and target.has_method("apply_status_effect"):
		var lvl_idx = clamp(skill_level - 1, 0, power_per_level.size() - 1)
		var total_power = power_per_level[lvl_idx]
		
		# 1. Apply Scaling LEGOs
		for factor in scaling_factors:
			total_power += caster.get_total(factor.stat) * factor.scale_amount
		
		# 2. Apply the Status
		target.apply_status_effect(status_id, duration, 1, total_power, caster)
		
		# 3. Inject the specific stat directly into the dictionary!
		if target.get("status_container") != null:
			var status_node = target.status_container.get_node_or_null(status_id)
			if status_node:
				# Map the Enum to the String and pack the dictionary
				if Unit.STAT_MAP.has(target_stat):
					var stat_string = Unit.STAT_MAP[target_stat]
					status_node.stats_to_buff = { stat_string: total_power }
				else:
					push_warning("Effect_ApplyStats: Stat not found in STAT_MAP!")

				# Inject any extra variables (like damage_ramp_cap)
				for key in extra_data:
					if key in status_node:
						status_node.set(key, extra_data[key])
				
				# Tell the unit to recalculate immediately so the buff takes effect instantly
				if target.has_method("recalculate_stats"):
					target.recalculate_stats()
