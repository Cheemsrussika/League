extends ItemEffect
class_name EffectSlowOnHit

@export var slow_melee: float = 0.30 
@export var slow_ranged: float = 0.15
@export var duration: float = 1.0

var slows_applied: int = 0

func on_attack_hit_post_mitigation(user: Unit, context: Dictionary) -> void:
	_apply_slow_logic(user, context)

func on_hit(user: Unit, context: Dictionary) -> void:
	_apply_slow_logic(user, context)
func on_attack(user: Unit, context: Dictionary) -> void:
	_apply_slow_logic(user, context)

func _apply_slow_logic(user: Unit, context: Dictionary) -> void:
	if not _try_start_cooldown(): return 

	var target = context.get("target")
	if not target or not is_instance_valid(target): return
	if not context.get("allow_on_hits", true): return

	# Correctly ignore towers
	if target.get("unit_type") == Unit.UnitType.TOWER: return

	var is_unit_ranged = user.is_ranged() if user.has_method("is_ranged") else false
	var slow_amount = slow_ranged if is_unit_ranged else slow_melee
	
	# --- THE PROPER WAY: Use your Unit's built-in function! ---
	if target.has_method("apply_status_effect"):
		# Apply the buff using the ID string, just like the Burn script!
		target.apply_status_effect("generic_slow", duration, 1, slow_amount, user)
		
		# Now, find the node we just created to ensure the variables are set correctly
		if target.get("status_container"):
			var status = target.status_container.get_node_or_null("generic_slow")
			if status:
				# Safely inject the slow amount
				if "slow_amount" in status:
					status.slow_amount = slow_amount
				elif "amount" in status:
					status.amount = slow_amount
					
		slows_applied += 1
		_update_item_ui(user)

func _update_item_ui(user):
	if user.inventory and user.inventory.has_method("request_ui_refresh"):
		user.inventory.request_ui_refresh()

func get_tooltip_extra() -> String:
	return "Enemies Slowed: %d" % slows_applied
