# res://Skills/Effects/Effect_Heal.gd
extends SkillEffect
class_name Effect_Heal

@export var is_self_heal: bool = true

@export_group("Base Values")
@export var base_heal: Array[float] = [50.0, 80.0, 110.0, 140.0, 170.0]

@export_group("Scaling")
# Add any stat scaling here (AP, AD, even Armor!)
@export var scaling_factors: Array[ScalingFactor] = []

@export_group("Hp% missing Scaling")
# 0.1 means 10% of missing health is added to the heal
@export var missing_hp_scaling: float = 0.0 

func on_execute(caster: Node2D, skill_level: int, target_data: Dictionary, _ref: Resource) -> void:
	var target = caster if is_self_heal else target_data.get("target_unit")
	
	if target and target.has_method("get_total"):
		var lvl_idx = clamp(skill_level - 1, 0, base_heal.size() - 1)
		var amount = base_heal[lvl_idx]
		
		# 1. Process Standard Stat Scaling Factors
		if caster.has_method("get_total"):
			for factor in scaling_factors:
				if factor:
					# Check source (defaulting to Caster if the variable isn't in your resource yet)
					var source_node = caster
					if "source" in factor and factor.source == 1: # 1 = Target
						source_node = target
						
					if source_node.has_method("get_total"):
						amount += source_node.get_total(factor.stat) * factor.scale_amount
		
		# 2. Process Special Missing HP Scaling
		if missing_hp_scaling > 0:
			var max_hp = target.get_total(Unit.Stat.HP)
			var missing_hp = max_hp - target.current_hp
			amount += missing_hp * missing_hp_scaling
		
		# 3. Apply the Heal
		if target.has_method("heal"):
			target.heal(amount)
		elif "current_hp" in target:
			target.current_hp = min(target.current_hp + amount, target.get_total(Unit.Stat.HP))
			
		print("Healed for: ", amount)
