extends ItemEffect
class_name EffectWarmogs

@export var regen_percent: float = 0.025 
@export var combat_cooldown: float = 6.0
@export var tick_rate: float = 0.5     

var time_accumulator: float = 0.0
var healed:float=0

func on_update(user: Unit, delta: float) -> void:
	var max_hp = user.get_total(user.Stat.HP)
	if user.current_health >= max_hp:
		time_accumulator = 0.0 
		return
	var current_time = Time.get_ticks_msec()
	if (current_time - user.last_combat_time) < (combat_cooldown * 1000):
		time_accumulator = 0.0 
		return
	time_accumulator += delta
	
	if time_accumulator >= tick_rate:
		var heal_amount = (max_hp * regen_percent* user.get_total(user.Stat.HP5)/5) * tick_rate 
		user.heal(heal_amount, null) 
		healed+=heal_amount
		time_accumulator -= tick_rate
func _update_item_ui(user):
	if user.inventory and user.inventory.has_method("request_ui_refresh"):
		user.inventory.request_ui_refresh()

func get_tooltip_extra() -> String:
	var text = "\nHealing Done: %d" % healed
	return text
