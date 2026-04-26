extends ItemEffect
class_name ItemEffect_ThresholdProc

@export_group("Proc Conditions")
@export var stacks_required: int = 2
@export var stack_window_seconds: float = 2.0
@export var cooldown_seconds: float = 6.0

@export_group("Proc Payloads (Drop SkillEffects Here!)")
@export var payloads: Array[ItemEffect] 

# Internal Tracking
var target_stacks: Dictionary = {}
var item_cooldown_timer: float = 0.0 

func on_damage_dealt(user: Unit, context: Dictionary):
	# FIX 1: Ignore damage that comes from other items! Procs cannot stack procs!
	var category = context.get("category", "")
	if category == "proc": return 

	var target = context.get("target")
	if not is_instance_valid(target): return
	
	var current_time = Time.get_ticks_msec() / 1000.0

	# 1. Check Cooldown
	if current_time < item_cooldown_timer: return 

	# 2. Initialize tracking for this target if they don't exist
	if not target_stacks.has(target):
		target_stacks[target] = {"count": 0, "first_hit_time": current_time}

	# 3. Check if the stack window expired
	if current_time - target_stacks[target]["first_hit_time"] > stack_window_seconds:
		target_stacks[target]["count"] = 0
		target_stacks[target]["first_hit_time"] = current_time

	# 4. Add a stack!
	target_stacks[target]["count"] += 1
	print("Stacks on ", target.name, ": ", target_stacks[target]["count"])

	# 5. DID WE HIT THE THRESHOLD?
	if target_stacks[target]["count"] >= stacks_required:
		# FIX 2: Reset stacks and trigger cooldown BEFORE firing the payload!
		# This prevents the synchronous signal loop from bypassing the cooldown.
		target_stacks.erase(target)
		item_cooldown_timer = current_time + cooldown_seconds
		
		# NOW it is safe to trigger the payload!
		_trigger_proc(user, target, context)


func _trigger_proc(user: Unit, target: Unit, context: Dictionary):
	print("THRESHOLD MET! Triggering Item Payload!")
	
	# We still package the context just in case a payload needs to know who we hit
	var trigger_context = context.duplicate()
	trigger_context["is_item_proc"] = true # Helps prevent infinite proc loops
	
	# Fire off every ItemEffect LEGO attached to this item (Damage, Shield, Heal, etc.)
	for effect in payloads:
		if effect and effect.has_method("execute_payload"):
			effect.execute_payload(user, target, trigger_context)
		else:
			print("WARNING: Payload %s does not have an execute_payload function!" % effect.resource_name)
