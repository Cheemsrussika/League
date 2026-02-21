extends ItemEffect
class_name EffectGrievousWounds

enum TriggerType { PHYSICAL, MAGIC, TRUE, ALL }

@export_group("Grievous Wounds")
@export var trigger_type: TriggerType = TriggerType.PHYSICAL
@export var wound_duration: float = 3.0

func on_damage_dealt(user: Unit, context: Dictionary) -> void:
	var damage_amount = context.get("amount", 0.0)
	if damage_amount <= 0: return
	_apply_logic(user, context)

func on_attack(user: Unit, context: Dictionary) -> void:
	if not context.has("damage_type"): context["damage_type"] = "physical"
	_apply_logic(user, context)

func _apply_logic(user: Unit, context: Dictionary) -> void:
	var type_str = str(context.get("damage_type", context.get("type", ""))).to_lower()
	var target = context.get("target")
	
	if not target or not is_instance_valid(target): return

	var matches = false
	match trigger_type:
		TriggerType.ALL: matches = true
		TriggerType.PHYSICAL: matches = (type_str == "physical")
		TriggerType.MAGIC: matches = (type_str == "magic")
		TriggerType.TRUE: matches = (type_str == "true")
		
	if matches and target.has_method("apply_status_effect"):
		target.apply_status_effect("grevious_wounds", wound_duration, 1, 0.0, user)
