# EffectSlowDynamic.gd
extends ItemEffect
class_name EffectSlowOnHit

@export var slow_melee: float = 0.30 
@export var slow_ranged: float = 0.15
@export var duration: float = 1.0

var slows_applied: int = 0

func on_attack(user: Champion, context: Dictionary) -> void:
	var current_time = Time.get_ticks_msec()
	if current_time - last_trigger_time < (cooldown * 1000):
		return 
	var target = context.get("target")
	if target.unit_type == Unit.UnitType.TOWER:
			return
	if not target or not is_instance_valid(target): return
	if not target.has_method("apply_slow"): return
	var slow_amount = slow_ranged if user.is_ranged() else slow_melee
	target.apply_slow(slow_amount, duration)
	slows_applied += 1
	_update_item_ui(user)
	# 5. Reset Cooldown
	last_trigger_time = current_time

func _update_item_ui(user):
	if user.inventory and user.inventory.has_method("request_ui_refresh"):
		user.inventory.request_ui_refresh()
func get_tooltip_extra() -> String:
	return "Enemies Slowed: %d" % slows_applied
