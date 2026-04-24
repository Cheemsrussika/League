extends ItemEffect
class_name EffectBloodthirster

@export_group("Shield Config")
@export var shield_id: String = "bt_shield"
@export var max_shield_base: float = 140.0
@export var max_shield_lvl_scaling: float = 310.0
@export var shield_duration: float = 25.0

var total_shield_generated: float = 0.0
func on_heal(user: Unit, context: Dictionary):
	var amount = context.get("amount", 0.0)
	if amount <= 0: return

	var level = user.get("level") if "level" in user else 1
	var level_factor = (level - 1) / 17.0 
	var shield_cap = lerp(max_shield_base, max_shield_lvl_scaling, level_factor) 
	
	var max_hp = user.get_total(Unit.Stat.HP)
	var current_hp = user.current_health
	var added_shield = 0.0

	# Logic for capping and splitting (Same as before)
	if current_hp >= max_hp:
		var room_left = shield_cap - user.total_shield_amount
		added_shield = min(amount, room_left)
		context["amount"] = 0.0
	elif current_hp + amount > max_hp:
		var healing_needed = max_hp - current_hp
		added_shield = min(amount - healing_needed, shield_cap - user.total_shield_amount)
		context["amount"] = healing_needed

	# --- IMPROVED SHIELD APPLICATION ---
	if added_shield > 0:
		total_shield_generated += added_shield
		_apply_or_refresh_bt_shield(user, added_shield)

func _apply_or_refresh_bt_shield(user: Unit, amount: float):
	# Search for an existing BT shield in the array
	# We use "bt_shield" as a unique identifier
	var found = false
	for s in user.active_shields:
		if s.get("id") == "bt_shield":
			s["amount"] = min(s["amount"] + amount, 500.0) # Power cap logic here
			s["duration"] = shield_duration # Reset duration
			found = true
			break
	
	if not found:
		# Create a new shield entry with an "id" key
		var new_shield = {
			"id": "bt_shield", # We add this key manually
			"amount": amount, 
			"max_amount": amount,
			"duration": shield_duration, 
			"max_duration": shield_duration,
			"type": 0, # ShieldType.ALL
			"decay_mode": 1 # ShieldDecay.TIMEOUT
		}
		user.active_shields.append(new_shield)
	
	user._recalc_total_shield()

func get_tooltip_extra() -> String:
	return "Total Shield Generated: [color=yellow]%.0f[/color]" % total_shield_generated
