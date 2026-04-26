extends ItemEffect
class_name ItemEffect_GrantShield

@export_group("Trigger Condition")
@export var is_lifeline: bool = false # True for Sterak's, False for Eclipse
@export var lifeline_threshold_percent: float = 0.30


@export_group("Shield Properties")
@export var shield_duration: float = 3.0
@export_enum("All Damage", "Physical Only", "Magic Only") var shield_damage_type: int = 0
@export_enum("Permanent", "Standard", "Decaying") var shield_decay_mode: int = 1

@export_group("Shield Scaling (Use ScalingFactor LEGOs!)")
@export var base_shield: float = 0.0
@export var scalings: Array[ScalingFactor] = [] # Let your LEGOs do the math!



# 1. Standard trigger (Listens to taking damage for Lifeline items)
func on_take_damage(user: Unit, _context: Dictionary) -> void:
	if not is_lifeline: return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_trigger_time < cooldown: return
		
	var max_hp = user.get_total(Unit.Stat.HP)
	var health_percent = user.current_health / max(1.0, max_hp)
	
	if health_percent <= lifeline_threshold_percent:
		trigger_shield(user)

# 2. Direct trigger (Called by ItemEffect_ThresholdProc for Eclipse)
func execute_payload(user: Unit, _target: Unit, _context: Dictionary):
	trigger_shield(user)

# 3. The actual Shield Math
func trigger_shield(user: Unit):
	last_trigger_time = Time.get_ticks_msec() / 1000.0
	var total_shield = base_shield
	
	# Let your ScalingFactors handle Level, AD, Max HP, etc.!
	for factor in scalings:
		total_shield += factor.calculate_value(user, user)
		
	if user.has_method("add_shield"):
		user.add_shield(total_shield, shield_duration, shield_damage_type, shield_decay_mode)
		print("SHIELD GRANTED! Amount: ", total_shield)
