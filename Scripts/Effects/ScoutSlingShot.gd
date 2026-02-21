extends ItemEffect
class_name EffectScoutsSlingshot

enum DamageType { PHYSICAL, MAGIC, TRUE }

@export_group("Stats")

@export var bonus_damage: float = 40.0
@export var internal_cooldown: float = 10.0
@export var reduction_per_hit: float = 1.0
@export var damage_type: DamageType = DamageType.PHYSICAL

var next_ready_time: int = 0

func on_damage_dealt(user: Champion, context: Dictionary) -> void:
	if context["amount"] <= 0 or not is_instance_valid(context["target"]):
		return
	if context.get("category") == "proc":
		return

	var current_time = Time.get_ticks_msec()
	if current_time >= next_ready_time:
		var target = context["target"]
		var text="physical"
		if damage_type==1:
			text="magic"
		elif damage_type==2:
			text="true"
		var dealt = user.deal_damage(target, bonus_damage,text, "proc", false)
		if tracker:
			tracker["damage"] += dealt
			tracker["procs"] += 1
		next_ready_time = current_time + int(internal_cooldown * 1000.0)

	else:
		next_ready_time -= int(reduction_per_hit * 1000.0)

func get_tooltip_extra() -> String:
	var current_time = Time.get_ticks_msec()
	var time_left_sec = (next_ready_time - current_time) / 1000.0
	var text =super.get_tooltip_extra()
	if time_left_sec > 0:
		text += "[color=red]Cooldown: %.1fs[/color]" % time_left_sec
	else:
		text += "[color=green]Ready[/color]"
	return text
