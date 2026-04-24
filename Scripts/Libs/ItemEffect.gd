# ItemEffect.gd
extends Resource
class_name ItemEffect

@export_group("Identity")
@export var id: String = ""         # e.g., "passive_sheen"
@export var is_unique: bool = false # TODO: Implement unique check in Inventory
@export var cooldown: float = 0.0   # TODO: Implement cooldown check
var last_trigger_time: int = -9999999

var tracker: Dictionary = {
	"damage": 0.0,
	"healing": 0.0,
	"procs": 0
}

func _try_start_cooldown() -> bool:
	var current_time = Time.get_ticks_msec()
	var cooldown_ms = cooldown * 1000.0
	if current_time < last_trigger_time + cooldown_ms:
		return false 
	last_trigger_time = current_time
	return true

func get_tooltip_extra() -> String:
	var text=""
	if tracker.damage>0:
		text+= str("Damage dealt:%.1f\n"%[tracker.damage])
	if tracker.healing:
		text+= str("Healed:%.1f\n"%[tracker.healing])
	if tracker.procs:
		text+=str("Time procs:%.1f\n"%[tracker.procs])
	return text
	
func on_equip(user: Champion) -> void:
	pass

func on_unequip(user: Champion) -> void:
	pass

func on_attack(user: Unit, context: Dictionary) -> void:
	pass

func on_hit_received(user: Unit, context: Dictionary) -> void:
	pass

func on_kill(user: Unit, context: Dictionary) -> void:
	pass
func on_update(user: Unit, delta: float) -> void:
	pass
func on_active(user: Unit, context: Dictionary) -> void:
	pass
func on_ability_cast(user: Champion, context: Dictionary) -> void:
	pass
func on_incoming_damage_calculation(user: Champion, damage: float, type: String) -> float:
	return damage
func on_stat_calculation(unit):
	pass
func on_calculate_hit_damage(unit, context):
	pass
func on_hit(user: Unit, context: Dictionary) -> void:
	pass
func on_damage_dealt(user: Unit, context: Dictionary):
	pass
func on_event(hook: String, owner: Unit, data: Dictionary):
	match hook:
		"on_attack":
			on_attack(owner, data) 
		"on_hit":
			on_hit(owner, data)
		"on_hit_received":
			on_hit_received(owner, data)
		"on_damage_dealt":
			on_damage_dealt(owner, data)
