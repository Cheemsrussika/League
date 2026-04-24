extends ItemEffect
class_name EffectProcing

@export var bonus_damage: float = 50.0
@export var target_must_be_champion: bool = true

var total_damage: float = 0.0 # Tracking stat

func on_damage_dealt(owner: Unit, context: Dictionary):
	var category = context.get("category", "")
	var target = context.get("target")
	if category == "proc": return
	if target_must_be_champion and not (target is Champion):
		return
	if not _try_start_cooldown():
		return 
	var dealt = owner.deal_damage(target, bonus_damage, "magic", "proc")
	
	total_damage += dealt
	_update_item_ui(owner)



func _update_item_ui(user):
	if user.get("inventory") and user.inventory.has_method("request_ui_refresh"):
		user.inventory.request_ui_refresh()

func get_tooltip_extra() -> String:
	var current_time = Time.get_ticks_msec()
	var cooldown_ms = cooldown * 1000.0
	var finish_time = last_trigger_time + cooldown_ms
	var time_left_sec = (finish_time - current_time) / 1000.0
	
	var text = "Total Damage Dealt: [color=yellow]%d[/color]\n" % int(total_damage)
	
	if time_left_sec > 0:
		text += "[color=red]Cooldown: %.1fs[/color]" % time_left_sec
	else:
		text += "[color=green]Ready[/color]"
		
	return text
