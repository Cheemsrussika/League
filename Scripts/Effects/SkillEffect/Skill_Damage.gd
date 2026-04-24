# res://Skills/Effects/Effect_Damage.gd
extends SkillEffect
class_name Effect_Damage

@export_enum("physical", "magic", "true") var damage_type: String = "physical"
@export var base_damage: Array[float] = [80.0, 120.0, 160.0, 200.0, 240.0]

# This is the magic part: a list of scaling LEGOs
@export var scaling_factors: Array[ScalingFactor] = []
@export_group("Execution Logic")
## Percentage of missing health to deal as bonus damage (e.g. 0.25 = 25%)
@export var missing_hp_scaling: float = 0.0

@export_group("On-Hit Settings")
@export var is_on_hit: bool = false
@export var allow_lifesteal: bool = false
@export var on_hit_multiplier: float = 1.0

func on_execute(caster: Node2D, skill_level: int, target_data: Dictionary, _ref: Resource) -> void:
	var target = target_data.get("target_unit")
	if target and target.has_method("take_damage"):
		var lvl_idx = clamp(skill_level - 1, 0, base_damage.size() - 1)
		var total_dmg = base_damage[lvl_idx]
		
		# 1. Standard Scaling (AD/AP)
		for factor in scaling_factors:
			total_dmg += caster.get_total(factor.stat) * factor.scale_amount
		
		# 2. Execution Scaling (Garen R Logic)
		if missing_hp_scaling > 0 and "current_health" in target and "max_health" in target:
			var missing_hp = target.max_health - target.current_health
			total_dmg += missing_hp * missing_hp_scaling
		var effective_on_hit = _ref.get("is_on_hit") if _ref else is_on_hit
		var effective_lifesteal = _ref.get("allow_lifesteal") if _ref else allow_lifesteal
		var effective_mult = _ref.get("on_hit_multiplier") if _ref else on_hit_multiplier

		var skill_context = {
			"allow_on_hits": effective_on_hit,
			"allow_lifesteal": effective_lifesteal,
			"on_hit_mult": effective_mult
		}
		
		var final_category = "attack" if effective_on_hit else "spell"
				
		caster.deal_damage(target, total_dmg, damage_type, final_category, false, skill_context)
