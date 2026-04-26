# res://Skills/Effects/Effect_Damage.gd
extends SkillEffect
class_name Effect_Damage

@export_enum("physical", "magic", "true") var damage_type: String = "physical"
@export var base_damage: Array[float] = [80.0, 120.0, 160.0, 200.0, 240.0]
@export var can_spell_crit: bool = false
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
			# --- BUG FIX: Use our smart function so Caps and Target scaling actually work! ---
			total_dmg += factor.calculate_value(caster, target)
		
		# 2. Execution Scaling (Garen R Logic)
		if missing_hp_scaling > 0 and "current_health" in target and "max_health" in target:
			var missing_hp = target.max_health - target.current_health
			total_dmg += missing_hp * missing_hp_scaling
			
		# 3. --- NEW: APPLY SKILL DAMAGE MULTIPLIER ---
		# We multiply this AFTER all the flat base/scaling damage is added together!
		var skill_mult = caster.get_total(Unit.Stat.SKILL_DAMAGE_MULT)
		total_dmg *= (1.0 + skill_mult)
			
		var effective_on_hit = _ref.get("is_on_hit") if _ref else is_on_hit
		var effective_lifesteal = _ref.get("allow_lifesteal") if _ref else allow_lifesteal
		var effective_mult = _ref.get("on_hit_multiplier") if _ref else on_hit_multiplier

		# Check if the hitbox told us this is an AoE spell!
		var is_aoe = target_data.get("is_aoe", false)
		var is_a_crit = false
		
		if can_spell_crit:
			# Roll a random number between 0.0 and 100.0
			var roll = randf() * 100.0
			if roll <= caster.get_total(Unit.Stat.CRIT):
				is_a_crit = true
				
		if effective_on_hit:
			# 1. Prepare the context for items like Sheen
			var on_hit_context = {
				"target": target,
				"damage": total_dmg,
				"is_crit": false,
				"damage_type": damage_type,
				"on_hit_mult": effective_mult
			}

			# 2. Trigger the passives that Sheen listens to
			caster._trigger_passive_effects("on_attack", on_hit_context)

			# 3. Update damage in case Sheen added bonus damage to the context
			total_dmg = on_hit_context["damage"]

		var is_basic_attack = target_data.get("is_basic_attack", false)
		var final_category = "attack" if is_basic_attack else "spell"

		# Pack EVERYTHING into the context so Items don't miss it!
		var skill_context = {
			"allow_on_hits": effective_on_hit,
			"allow_lifesteal": effective_lifesteal,
			"on_hit_mult": effective_mult,
			"is_aoe": is_aoe,               # Important for Omnivamp penalties
			"amount": total_dmg,            # Black Cleaver needs this
			"damage_type": damage_type,     # Burn and Cleaver need this
			"category": final_category      # Burn needs this
		}
		print("dmage: ",total_dmg)
		
		caster.deal_damage(target, total_dmg, damage_type, final_category, is_a_crit, skill_context)
