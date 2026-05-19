# res://Skills/Effects/Effect_Damage.gd
extends SkillEffect
class_name Effect_Damage

@export_enum("physical", "magic", "true") var damage_type: String = "physical"
@export var base_damage: Array[float] = [80.0, 120.0, 160.0, 200.0, 240.0]
@export var can_spell_crit: bool = false
@export var scaling_factors: Array[ScalingFactor] = []

@export_group("Execution Logic")
@export var missing_hp_scaling: float = 0.0

@export_group("On-Hit Settings")
@export var is_on_hit: bool = false
@export var allow_lifesteal: bool = false
@export var on_hit_multiplier: float = 1.0

func on_execute(caster: Node2D, skill_level: int, target_data: Dictionary, _ref: Resource) -> void:
	var target = target_data.get("target_unit")
	if target and target.team == caster.team: 
		return
	if target and target.has_method("take_damage"):
		var lvl_idx = clamp(skill_level - 1, 0, base_damage.size() - 1)
		var total_dmg = base_damage[lvl_idx]
		
		# 1. Standard Scaling
		for factor in scaling_factors:
			total_dmg += factor.calculate_value(caster, target)
		
		# 2. Execution Scaling
		if missing_hp_scaling > 0 and "current_health" in target and "max_health" in target:
			var missing_hp = target.max_health - target.current_health
			total_dmg += missing_hp * missing_hp_scaling
			
		# 3. Apply Skill Multiplier
		var skill_mult = caster.get_total(Unit.Stat.SKILL_DAMAGE_MULT)
		total_dmg *= (1.0 + skill_mult)
			
		var effective_on_hit = _ref.get("is_on_hit") if _ref else is_on_hit
		var effective_lifesteal = _ref.get("allow_lifesteal") if _ref else allow_lifesteal
		var effective_mult = _ref.get("on_hit_multiplier") if _ref else on_hit_multiplier
		var is_aoe = target_data.get("is_aoe", false)
		var is_a_crit = false
		
		if can_spell_crit:
			var roll = randf() * 100.0
			if roll <= caster.get_total(Unit.Stat.CRIT):
				is_a_crit = true

		# --- FIX 1: NATIVE BUCKET CREATION ---
		# We start our bucket with the primary skill damage
		var damage_buckets = { damage_type: total_dmg }
				
		if effective_on_hit:
			# 1. Prepare Context (Pass the bucket by reference!)
			var on_hit_context = {
				"target": target,
				"is_crit": is_a_crit,
				"damage_type": damage_type, # The primary type
				"on_hit_mult": effective_mult,
				"buckets": damage_buckets 
			}

			# 2. Trigger passives
			# Items like your example will now safely inject new keys into 'damage_buckets'
			caster._trigger_passive_effects("on_attack", on_hit_context)

		var is_basic_attack = target_data.get("is_basic_attack", false)
		var final_category = "attack" if is_basic_attack else "spell"

		# --- FIX 2: LOOP AND EXECUTE THE BUCKETS ---
		for current_type in damage_buckets.keys():
			var amount = damage_buckets[current_type]
			
			# Skip empty buckets so we don't spawn "0" damage floating texts
			if amount <= 0: 
				continue

			var skill_context = {
				"allow_on_hits": effective_on_hit,
				"allow_lifesteal": effective_lifesteal,
				"on_hit_mult": effective_mult,
				"is_aoe": is_aoe,               
				"amount": amount,             
				"damage_type": current_type, # <-- CRUCIAL: Uses the specific bucket type
				"category": final_category      
			}
		
			if caster.has_method("deal_damage"):
				# Champion routing pipeline
				caster.deal_damage(target, amount, current_type, final_category, is_a_crit, skill_context)
			else:
				# Monster direct pipeline
				if target.has_method("take_damage"):
					target.take_damage(amount, current_type, caster)
