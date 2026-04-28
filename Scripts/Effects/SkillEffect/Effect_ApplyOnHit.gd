# res://Skills/Effects/Effect_ApplyOnHit.gd
extends SkillEffect
class_name Effect_ApplyOnHit

@export_group("Status Setup")
@export var status_id: String = "empowered_hit"
@export var duration: float = 5.0

@export_group("Damage Configuration")
## Base damage added to the attack bucket per skill level
@export var power_per_level: Array[float] = [20.0, 40.0, 60.0, 80.0, 100.0]
@export_enum("physical", "magic", "true") var damage_type: String = "physical"

@export_group("Scaling")
## Add AD/AP/HP scaling factors here
@export var scaling_factors: Array[ScalingFactor] = []

@export_group("Extra Utility")
## e.g., {"silence_duration": 1.5, "slow_amount": 0.2}
@export var extra_data: Dictionary = {}

func on_execute(caster: Node2D, skill_level: int, _target_data: Dictionary, _ref: Resource) -> void:
	# On-hit buffs are almost always applied to the caster (self)
	var target = caster 
	
	if target and target.has_method("apply_status_effect"):
		var lvl_idx = clamp(skill_level - 1, 0, power_per_level.size() - 1)
		var base_power = power_per_level[lvl_idx]
		
		# 1. Apply the Status to the Caster
		target.apply_status_effect(status_id, duration, 1, base_power, caster)
		
		# 2. Inject the On-Hit LEGOs
		var status_node = target.get_node_or_null("StatusContainer/" + status_id)
		if status_node:
			# Pass the essential bucket data
			if "bonus_damage_base" in status_node:
				status_node.bonus_damage_base = base_power
			
			if "damage_type" in status_node:
				status_node.damage_type = damage_type
				
			if "scaling_factors" in status_node:
				status_node.scaling_factors = scaling_factors
				
			# Pass the utility (Silence, Slows, etc.)
			for key in extra_data:
				if key in status_node:
					status_node.set(key, extra_data[key])
			DevMenu.add_log("On hit status applied: %s (%s :%s)"%[status_id,base_power,damage_type])
			
