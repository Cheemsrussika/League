extends ItemEffect
class_name EffectBurn

enum TriggerType { PHYSICAL, MAGIC, TRUE, ALL }

@export_group("Burn Triggers")
@export var trigger_type: TriggerType = TriggerType.MAGIC 
@export var trigger_on_attacks: bool = false 
@export var trigger_on_spells: bool = true   

@export_group("Burn Config")
@export var burn_id: String = "item_burn"
@export var duration: float = 3.0
@export var tick_rate: float = 0.5 

@export_group("Damage")
@export var base_damage_per_tick: float = 5.0
@export var ap_ratio_per_tick: float = 0.02 
@export var target_max_hp_ratio: float = 0.01 
@export var damage_cap_monsters: float = 20.0

var total_damage: float = 0.0

func on_damage_dealt(user: Unit, context: Dictionary):
	var category = context.get("category", "proc")
	if category == "proc": return
	if category == "attack" and not trigger_on_attacks: return
	if category == "spell" and not trigger_on_spells: return

	var target = context.get("target")
	if not target or not is_instance_valid(target): return
	if target.unit_type == Unit.UnitType.TOWER: return

	# Check Damage Type
	var type_str = str(context.get("damage_type", context.get("type", ""))).to_lower()
	var matches_type = false
	match trigger_type:
		TriggerType.ALL: matches_type = true
		TriggerType.PHYSICAL: matches_type = (type_str == "physical")
		TriggerType.MAGIC: matches_type = (type_str == "magic")
		TriggerType.TRUE: matches_type = (type_str == "true")
		
	if not matches_type: return

	# --- CALCULATE DAMAGE ---
	var tick_dmg = base_damage_per_tick
	if ap_ratio_per_tick > 0: tick_dmg += user.get_total(Unit.Stat.AP) * ap_ratio_per_tick
	if target_max_hp_ratio > 0: tick_dmg += target.get_total(Unit.Stat.HP) * target_max_hp_ratio
	if target.unit_type == Unit.UnitType.MINION: tick_dmg *= 4.0
	elif target.unit_type == Unit.UnitType.MONSTER and damage_cap_monsters > 0:
		tick_dmg = min(tick_dmg, damage_cap_monsters)

	# --- APPLY STATUS ---
	if target.has_method("apply_status_effect"):
		target.apply_status_effect(burn_id, duration, 1, tick_dmg, user)
		var status = target.status_container.get_node_or_null(burn_id)
		if status:
			status.tick_rate = tick_rate
			status.damage_per_tick = tick_dmg
			status.damage_type = "magic"
			status.caster = user 
			if "_timer" in status:
				status._timer = 0.0


func on_status_tick_damage(user: Unit, context: Dictionary):
	if context.get("status_id") == burn_id:
		total_damage += context["receipt"]["mitigated"]

func get_tooltip_extra() -> String:
	return "Burn Damage: %.0f" % total_damage
