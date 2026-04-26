extends ItemEffect
class_name EffectProcing

@export_group("Trigger Settings")
@export var is_standalone_trigger: bool = true # TRUE = Hextech Alternator, FALSE = Eclipse Payload
@export var target_must_be_champion: bool = true
@export_enum("physical", "magic", "true") var damage_type: String = "magic"

@export_group("Damage Scaling (Use LEGOs!)")
@export var base_damage: float = 50.0
@export var scalings: Array[ScalingFactor] = [] # Let it scale with AP, AD, Level, etc!

var total_damage: float = 0.0 # Tracking stat

# --- 1. STANDALONE TRIGGER (E.g., Hextech Alternator) ---
func on_damage_dealt(owner: Unit, context: Dictionary):
	if not is_standalone_trigger: return # Let ThresholdProc handle it if false!
	
	var category = context.get("category", "")
	if category == "proc": return # Prevent items procing items infinitely
	
	var target = context.get("target")
	if not is_instance_valid(target): return
	
	if target_must_be_champion and target.unit_type != Unit.UnitType.CHAMPION:
		return
		
	if not _try_start_cooldown():
		return 
		
	_deal_proc_damage(owner, target)

# --- 2. PAYLOAD TRIGGER (E.g., Triggered by ThresholdProc) ---
func execute_payload(owner: Unit, target: Unit, _context: Dictionary):
	# We ignore the cooldown and standalone checks here because the ThresholdProc 
	# already did the math and told us it's time to fire!
	_deal_proc_damage(owner, target)

# --- 3. CORE DAMAGE MATH ---
func _deal_proc_damage(owner: Unit, target: Unit):
	var final_damage = base_damage
	
	# Calculate all the LEGO scalings attached to this effect
	for factor in scalings:
		if factor and factor.has_method("calculate_value"):
			final_damage += factor.calculate_value(owner, target)
			
	var dealt = owner.deal_damage(target, final_damage, damage_type, "proc")
	
	total_damage += dealt
	_update_item_ui(owner)

# --- HELPERS ---

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
