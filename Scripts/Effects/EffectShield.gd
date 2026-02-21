extends ItemEffect
class_name EffectShield

enum TriggerType { LOW_HEALTH, ACTIVE, MANA_SHIELD }

# --- NEW: SHIELD CONFIGURATION ---
# These match the Enums in Unit.gd (0=ALL, 1=PHYSICAL, 2=MAGIC)
@export_enum("All Damage", "Physical Only", "Magic Only") var shield_damage_type: int = 0

# These match the Enums in Unit.gd (0=NONE, 1=TIMEOUT, 2=DECAY)
@export_enum("Permanent", "Standard (Timeout)", "Decaying (Steraks)") var shield_decay_mode: int = 1

@export_group("Trigger Config")
@export var trigger_type: TriggerType = TriggerType.LOW_HEALTH
@export var trigger_threshold_percent: float = 0.30 

@export_group("Shield Stats")
@export var base_shield: float = 200.0
@export var shield_duration: float = 3.0

@export_group("Scaling")
@export var scale_percent_max_hp: float = 0.0 # Sterak's
@export var scale_percent_mana: float = 0.0   # Seraph's
@export var scale_percent_ad: float = 0.0     # Shieldbow



func on_take_damage(user: Champion, context: Dictionary) -> void:
	if trigger_type == TriggerType.LOW_HEALTH:
		_check_lifeline_trigger(user)

func _check_lifeline_trigger(user: Champion):
	# 1. Cooldown Check
	var current_time = Time.get_ticks_msec()
	if current_time - last_trigger_time < (cooldown * 1000): 
		return
		
	var max_hp = user.get_total(Unit.Stat.HP)
	var health_percent = user.current_health / max(1.0, max_hp)
	
	if health_percent <= trigger_threshold_percent:
		_activate_shield(user)

func _activate_shield(user: Champion):
	var current_time = Time.get_ticks_msec()
	last_trigger_time = current_time
	
	# 1. Calculate Amount
	var total_shield = base_shield
	
	if user.has_method("get_total"):
		total_shield += user.get_total(Unit.Stat.HP) * scale_percent_max_hp
		total_shield += user.get_total(Unit.Stat.MANA) * scale_percent_mana
		total_shield += user.get_total(Unit.Stat.AD) * scale_percent_ad

	# 2. Apply Shield with NEW parameters
	# We pass the type (Phys/Magic/All) and Decay (Timeout/Decaying)
	if user.has_method("add_shield"):
		# Arguments: Amount, Duration, Type, DecayMode
		user.add_shield(total_shield, shield_duration, shield_damage_type, shield_decay_mode)
		
		var type_name = ["Normal", "Physical", "Magic"][shield_damage_type]
		print("LIFELINE TRIGGERED! %s Shield: %s" % [type_name, total_shield])
	
	_update_item_ui(user)

func _update_item_ui(user):
	if user.inventory and user.inventory.has_method("request_ui_refresh"):
		user.inventory.request_ui_refresh()

func get_tooltip_extra() -> String:
	var current_time = Time.get_ticks_msec()
	var time_left = (last_trigger_time + (cooldown * 1000) - current_time) / 1000.0
	var active_time_assumed = time_left - (cooldown - shield_duration)
	var text="Shield Ready"
	if active_time_assumed>0:
		text += "[color=green]BUFF DURATION LEFT: %.1f[/color]\n"%active_time_assumed
	if time_left > 0:
		text+="Cooldown: %.1fs" % time_left
	else:
		text="Shield Ready"
	return text
