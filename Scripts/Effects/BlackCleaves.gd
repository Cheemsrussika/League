extends ItemEffect
class_name EffectBlackCleaver

@export var shred_per_stack: float = 0.05 
@export var max_stacks: int = 6
@export var duration: float = 6.0

func on_damage_dealt(user: Unit, context: Dictionary):
	var target = context.get("target")

	# 1. Base Safety Checks
	if not is_instance_valid(target): return
	if target.unit_type == Unit.UnitType.TOWER: return
	
	# 2. Figure out how much physical damage was dealt (Support both systems!)
	var physical_damage_dealt: float = 0.0
	
	# --- Alternative A: The Bucket System (Auto Attacks) ---
	if context.has("buckets"):
		var buckets = context.get("buckets")
		physical_damage_dealt = buckets.get("physical", 0.0)
		
	# --- Alternative B: Direct Damage (Spells like Garen E) ---
	elif context.has("damage_type") and context.has("amount"):
		if context.get("damage_type") == "physical":
			physical_damage_dealt = context.get("amount", 0.0)

	# 3. Apply the effect if physical damage was actually dealt
	if physical_damage_dealt > 0:
		print("Black Cleaver Triggered! Applying Shred to: ", target.name)
		
		if target.has_method("apply_status_effect"):
			target.apply_status_effect("armor_shred", duration, 1, shred_per_stack, user)
			
			if target.status_container:
				var status = target.status_container.get_node_or_null("armor_shred")
				if status and "max_stacks_allowed" in status:
					status.max_stacks_allowed = max_stacks
