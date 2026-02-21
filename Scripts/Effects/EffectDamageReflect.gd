extends ItemEffect
class_name EffectDamageReflect

@export_group("Reflection Stats")
@export var reflect_flat: float = 10.0
@export var reflect_percent_bonus_armor: float = 0.25 
@export var reflect_percent_max_hp: float = 0.0

@export_group("Grevious Wounds")
@export var apply_grevious_wounds: bool = true
@export var wound_duration: float = 3.0

func on_take_damage(user: Champion, context: Dictionary) -> void:
	# Match these to the keys in Champion.gd's post_context
	var source = context.get("attacker") 
	var damage_amount = context.get("amount", 0.0)
	var damage_type = context.get("type", "")     
	
	if not source or not is_instance_valid(source): return
	if source == user: return 
	if source.team == user.team: return
	if damage_type != "physical": return 

	var damage_to_return = reflect_flat

	var armor = user.get_total(Unit.Stat.AR) 
	damage_to_return += armor * reflect_percent_bonus_armor
	
	var max_hp = user.get_total(Unit.Stat.HP)
	damage_to_return += max_hp * reflect_percent_max_hp

	if damage_to_return > 0:
		# Note: We don't need to capture the receipt here unless we're tracking stats
		source.take_damage(damage_to_return, "magic", user, false)
		
		if apply_grevious_wounds and source.has_method("apply_status_effect"):
			# Ensure the power (3rd param) is passed if your status needs it
			source.apply_status_effect("grevious_wounds", wound_duration, 1, 0.40)
