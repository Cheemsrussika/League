extends ItemEffect
class_name EffectBlackCleaver

@export var shred_per_stack: float = 0.05 
@export var max_stacks: int = 6
@export var duration: float = 6.0

func on_attack(user: Unit, context: Dictionary):
	var target = context.get("target")
	var buckets = context.get("buckets")
	
	# 1. Safety Checks
	if not target or not buckets: return
	if not is_instance_valid(target): return
	
	# 2. Only apply if Physical Damage was dealt
	if buckets.get("physical", 0.0) > 0:

		if target.has_method("apply_status_effect"):
			target.apply_status_effect("armor_shred", duration, 1, shred_per_stack, user)
			if target.status_container:
				var status = target.status_container.get_node_or_null("armor_shred")
				if status:
					# Match the variable name in your StatusArmorShred.gd
					if "max_stacks_allowed" in status:
						status.max_stacks_allowed = max_stacks
