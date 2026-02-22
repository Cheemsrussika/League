extends ItemEffect
class_name EffectShield

enum TriggerType { LOW_HEALTH, ACTIVE, MANA_SHIELD }

# --- OLD CONFIGURATION (PRESERVED) ---
@export_group("Shield Identification")
# Matches Enums in Unit.gd (0=ALL, 1=PHYSICAL, 2=MAGIC)
@export_enum("All Damage", "Physical Only", "Magic Only") var shield_damage_type: int = 0
# Matches Enums in Unit.gd (0=NONE, 1=TIMEOUT, 2=DECAY)
@export_enum("Permanent", "Standard (Timeout)", "Decaying (Steraks)") var shield_decay_mode: int = 1

@export_group("Trigger Config")
@export var trigger_type: TriggerType = TriggerType.LOW_HEALTH
@export var trigger_threshold_percent: float = 0.30
@export var shield_duration: float = 3.0

# --- NEW CONFIGURATION (LEVEL & RANGE) ---
@export_group("Scaling Toggles")
@export var use_level_scaling: bool = true
@export var use_range_difference: bool = true

@export_group("Level Scaling (Melee)")
@export var melee_lvl_1: float = 200.0
@export var melee_lvl_18: float = 600.0

@export_group("Level Scaling (Ranged)")
@export var ranged_lvl_1: float = 150.0
@export var ranged_lvl_18: float = 450.0

@export_group("Stat Scalings")
@export var base_flat_shield: float = 0.0
@export var scale_percent_max_hp: float = 0.0 # Sterak's
@export var scale_percent_mana: float = 0.0   # Seraph's
@export var scale_percent_ad: float = 0.0     # Shieldbow



# --- CORE FUNCTIONS ---

# 1. Entry point called from Unit.gd
func on_take_damage(user: Unit, _context: Dictionary) -> void:
	if trigger_type == TriggerType.LOW_HEALTH:
		_check_lifeline_trigger(user)

# 2. Logic Check (Cooldown & Health)
func _check_lifeline_trigger(user: Unit):
	var current_time = Time.get_ticks_msec()
	if current_time - last_trigger_time < (cooldown * 1000): 
		return
		
	var max_hp = user.get_total(Unit.Stat.HP)
	var health_percent = user.current_health / max(1.0, max_hp)
	
	if health_percent <= trigger_threshold_percent:
		_activate_shield(user)

# 3. Shield Application
func _activate_shield(user: Unit):
	last_trigger_time = Time.get_ticks_msec()
	
	# Start with flat base
	var total_shield = base_flat_shield
	
	# Apply Level Scaling if enabled
	if use_level_scaling:
		var level = user.get("level") if "level" in user else 1
		var level_factor = clamp((level - 1) / 17.0, 0.0, 1.0)
		
		var start_val = melee_lvl_1
		var end_val = melee_lvl_18
		
		if use_range_difference and user.has_method("is_ranged") and user.is_ranged():
			start_val = ranged_lvl_1
			end_val = ranged_lvl_18
			
		total_shield += lerp(start_val, end_val, level_factor)

	# Apply Stat Scalings from your old version
	if user.has_method("get_total"):
		total_shield += user.get_total(Unit.Stat.HP) * scale_percent_max_hp
		total_shield += user.get_total(Unit.Stat.MANA) * scale_percent_mana
		total_shield += user.get_total(Unit.Stat.AD) * scale_percent_ad

	# Apply to Unit using Unit.gd's system
	if user.has_method("add_shield"):
		user.add_shield(total_shield, shield_duration, shield_damage_type, shield_decay_mode)
		
		var type_name = ["Normal", "Physical", "Magic"][shield_damage_type]
		print("LIFELINE TRIGGERED! %s Shield: %s" % [type_name, total_shield])
	
	_update_item_ui(user)

# --- HELPERS ---

func _update_item_ui(user):
	if user.inventory and user.inventory.has_method("request_ui_refresh"):
		user.inventory.request_ui_refresh()


func get_tooltip_extra() -> String:
	var current_time = Time.get_ticks_msec()
	var time_left = (last_trigger_time + (cooldown * 1000) - current_time) / 1000.0
	var active_time_assumed = time_left - (cooldown - shield_duration)
	
	var text = ""
	if active_time_assumed > 0:
		text += "[color=green]BUFF DURATION LEFT: %.1f[/color]\n" % active_time_assumed
	
	if time_left > 0:
		text += "Cooldown: %.1fs" % time_left
	else:
		text = "Shield Ready"
	return text
