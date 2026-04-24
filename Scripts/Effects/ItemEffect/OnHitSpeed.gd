extends ItemEffect
class_name EffectRage

enum TriggerType { PHYSICAL_ONLY, MAGIC_ONLY, ANY_DAMAGE }

@export_group("Trigger Config")
@export var trigger_type: TriggerType = TriggerType.PHYSICAL_ONLY
@export var speed_id: String = "rage_speed" # <--- UNIQUE ID PER ITEM

@export_group("Rage Stats")
@export var speed_bonus_on_hit: float = 20.0
@export var speed_bonus_on_kill: float = 60.0
@export var duration: float = 2.0

func on_damage_dealt(user: Unit, context: Dictionary) -> void:
	var type = context.get("damage_type", "").to_lower()
	var should_trigger = false
	
	match trigger_type:
		TriggerType.ANY_DAMAGE: should_trigger = true
		TriggerType.PHYSICAL_ONLY: should_trigger = (type == "physical" or type == "true")
		TriggerType.MAGIC_ONLY: should_trigger = (type == "magic" or type == "true")

	if should_trigger:
		_apply_speed(user, speed_bonus_on_hit)

func on_kill(user: Unit, context: Dictionary) -> void:
	_apply_speed(user, speed_bonus_on_kill)

func _apply_speed(user: Unit, amount: float):
	if user.has_method("apply_temp_speed"):
		user.apply_temp_speed(amount, duration, speed_id)
