# res://Skills/Effects/EffectSlowOnHit.gd
extends ItemEffect
class_name EffectSlowOnHit

@export var slow_melee: float = 0.30 
@export var slow_ranged: float = 0.15
@export var duration: float = 1.0

var slows_applied: int = 0

# Listen to the Post-Mitigation hook for Skills and Auto-Attacks
func on_attack_hit_post_mitigation(user: Unit, context: Dictionary) -> void:
	_apply_slow_logic(user, context)

# Listen to the "on_hit" hook (used by your TowerProjectile)
func on_hit(user: Unit, context: Dictionary) -> void:
	_apply_slow_logic(user, context)

func _apply_slow_logic(user: Unit, context: Dictionary) -> void:
	# Use parent logic to check/start cooldown
	if not _try_start_cooldown(): return 

	var target = context.get("target")
	if not target or not is_instance_valid(target): return
	
	# Respect the skill "Passport"
	if not context.get("allow_on_hits", true): return

	if target.get("unit_type") == Unit.UnitType.TOWER: return
	if not target.has_method("apply_slow"): return

	var is_unit_ranged = user.is_ranged() if user.has_method("is_ranged") else false
	var slow_amount = slow_ranged if is_unit_ranged else slow_melee
	
	target.apply_slow(slow_amount, duration)
	slows_applied += 1
	_update_item_ui(user)

func _update_item_ui(user):
	if user.inventory and user.inventory.has_method("request_ui_refresh"):
		user.inventory.request_ui_refresh()
func get_tooltip_extra() -> String:
	return "Enemies Slowed: %d" % slows_applied
