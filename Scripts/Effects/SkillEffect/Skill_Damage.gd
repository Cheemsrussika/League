# res://Skills/Effects/Effect_Damage.gd
extends SkillEffect
class_name Effect_Damage

@export_enum("physical", "magic", "true") var damage_type: String = "physical"
@export var base_damage: Array[float] = [80.0, 120.0, 160.0, 200.0, 240.0]

# This is the magic part: a list of scaling LEGOs
@export var scaling_factors: Array[ScalingFactor] = []

func on_execute(caster: Node2D, skill_level: int, target_data: Dictionary, _ref: Resource) -> void:
	var target = target_data.get("target_unit")
	if target and target.has_method("take_damage"):
		var lvl_idx = clamp(skill_level - 1, 0, base_damage.size() - 1)
		var total_dmg = base_damage[lvl_idx]
		
		# Calculate all scaling factors dynamically
		if caster.has_method("get_total"):
			for factor in scaling_factors:
				if factor:
					total_dmg += caster.get_total(factor.stat) * factor.scale_amount
			
		target.take_damage(total_dmg, damage_type, caster)
