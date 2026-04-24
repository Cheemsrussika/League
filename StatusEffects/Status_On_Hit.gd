# res://Statuses/Status_OnHit.gd
extends StatusEffect

# Data injected by Effect_ApplyStatus
var bonus_damage_base: float = 0.0
var scaling_factors: Array = [] # Can hold ScalingFactor resources
var damage_type: String = "physical"
var silence_duration: float = 0.0

func on_attack_landed(caster: Unit, context: Dictionary) -> void:
	var target = context.get("target")
	var buckets = context.get("buckets") # Get the bucket from the Champion
	
	if target and buckets != null:
		var total_bonus = bonus_damage_base
		
		# Calculate Scaling
		for factor in scaling_factors:
			var stat_provider = caster if factor.source == factor.ScaleSource.CASTER else target
			if stat_provider.has_method("get_total"):
				total_bonus += stat_provider.get_total(factor.stat) * factor.scale_amount
		
		# ADD TO THE BUCKET instead of calling deal_damage
		if buckets.has(damage_type):
			buckets[damage_type] += total_bonus
		else:
			buckets[damage_type] = total_bonus
			
		# Apply Silence (This remains a separate action)
		if silence_duration > 0:
			target.apply_status_effect("silenced", silence_duration, 1, 0.0, caster)
			
		expire()
