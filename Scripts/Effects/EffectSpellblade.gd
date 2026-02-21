extends ItemEffect
class_name EffectSpellblade

enum DamageType { PHYSICAL, MAGIC, TRUE }

@export_group("Scaling")
@export var base_damage_percent: float = 1.0  # 100% of Base AD
@export var ap_ratio: float = 0.0             # For Lich Bane (e.g., 0.5 for 50% AP)
@export var base_stat_source: Unit.Stat = Unit.Stat.AD

@export_group("Config")
@export var damage_type: DamageType = DamageType.PHYSICAL
@export var buff_duration: float = 10.0

var cooldown_ready_time: int = 0
const SHEEN_BUFF_ID = "sheen_proc_active"

func on_ability_activated(user: Unit, context: Dictionary) -> void:
	var current_time = Time.get_ticks_msec()
	if current_time < cooldown_ready_time: return
	user.apply_status_effect(SHEEN_BUFF_ID, buff_duration, 1, 0.0, user)
	
	# Set cooldown (usually 1.5s for Sheen, 2.5s for Lich Bane)
	cooldown_ready_time = current_time + int(cooldown * 1000)
	if user.inventory: user.inventory.request_ui_refresh()

func on_attack(user: Unit, context: Dictionary) -> void:
	var target = context.get("target")
	if not target or not is_instance_valid(target): return
	if user.has_status(SHEEN_BUFF_ID):
		var stat_key = Unit.STAT_MAP.get(base_stat_source, "attack_damage")
		var damage_amount = user.base_stats.get(stat_key, 0.0) * base_damage_percent
		if ap_ratio > 0:
			damage_amount += user.get_total(Unit.Stat.AP) * ap_ratio
		var type_str = "physical"
		match damage_type:
			DamageType.MAGIC: type_str = "magic"
			DamageType.TRUE:  type_str = "true"
		user.deal_damage(target, damage_amount, type_str, "proc", false)
		var status = user.status_container.get_node_or_null(SHEEN_BUFF_ID)
		if status: status.expire()
		
		if user.inventory: user.inventory.request_ui_refresh()
