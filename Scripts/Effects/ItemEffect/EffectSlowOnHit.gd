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

func _apply_slow_logic(user: Unit, context: Dictionary) -> void:
	if not _try_start_cooldown(): return 

	var target = context.get("target")
	if not target or not is_instance_valid(target): return
	if not context.get("allow_on_hits", true): return

	# Correctly ignore towers so we don't accidentally slow buildings
	if target.get("unit_type") == Unit.UnitType.TOWER: return
	
	# --- THE FIX: Look for the new Status Container! ---
	var status_container = target.get_node_or_null("StatusContainer")
	if not status_container: return

	var is_unit_ranged = user.is_ranged() if user.has_method("is_ranged") else false
	var slow_amount = slow_ranged if is_unit_ranged else slow_melee
	
	# Generate the buff using your global library
	var slow_script = StatusLibrary.get_effect_script("generic_slow")
	if slow_script:
		var slow_buff = slow_script.new()
		
		slow_buff.id = "generic_slow"
		slow_buff.duration = duration
		
		# NOTE: Make sure this variable name matches what you actually 
		# called it inside your StatusGenericSlow.gd script! 
		# It might be `amount`, `slow_amount`, or `slow_percent`.
		if "slow_amount" in slow_buff: 
			slow_buff.slow_amount = slow_amount 
		
		status_container.add_child(slow_buff)
		
		slows_applied += 1
		_update_item_ui(user)

func _update_item_ui(user):
	if user.inventory and user.inventory.has_method("request_ui_refresh"):
		user.inventory.request_ui_refresh()

func get_tooltip_extra() -> String:
	return "Enemies Slowed: %d" % slows_applied
