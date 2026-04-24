extends SkillEffect
class_name Effect_Shield

@export_group("Shield Settings")
@export var shield_id: String = "skill_shield"
@export var duration: float = 3.0
# Matches Unit.ShieldType (0=ALL, 1=PHYSICAL, 2=MAGIC)
@export var shield_type: Unit.ShieldType = Unit.ShieldType.ALL
# Matches Unit.ShieldDecay (0=NONE, 1=TIMEOUT, 2=DECAY)
@export var decay_mode: int = 1 

@export_group("Base Values")
@export var base_shield: Array[float] = [60.0, 100.0, 140.0, 180.0, 220.0]

@export_group("Scaling LEGOs")
@export var scaling_factors: Array[ScalingFactor] = []

func on_execute(caster: Node2D, skill_level: int, target_data: Dictionary, _ref: Resource) -> void:
	var target = target_data.get("target_unit")
	if target == null:
		target = caster
	print("Shield W11\n")
	if target and target.has_method("add_shield"):
	
		print("Shield W61\n")
		var lvl_idx = clamp(skill_level - 1, 0, base_shield.size() - 1)
		var total_shield = base_shield[lvl_idx]
		
		# Process the Scaling Factors (AD, AP, HP, etc.)
		if caster.has_method("get_total"):
			for factor in scaling_factors:
				if factor:
					total_shield += caster.get_total(factor.stat) * factor.scale_amount
		print("Shield W4\n")
		target.add_shield(total_shield, duration, shield_type, decay_mode, shield_id)
		print("Skill Shield Applied: ", total_shield)
	else:
		print("Shield Fail: Target has no add_shield method!")
