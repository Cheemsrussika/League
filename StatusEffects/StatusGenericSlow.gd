# GenericSlow.gd
extends StatusEffect

func on_apply(_unit):
	# Match this to the check in Unit.recalculate_stats
	type = "slow" 

func on_stat_calculation(unit):
	unit.is_slowed = true
	
	# We use the string key "movement_speed" because that's what STAT_MAP uses
	var ms_key = "move_speed" 
	
	# We subtract from the multiplier. (e.g., 1.0 + (-0.30) = 0.70 or 70% speed)
	var current_mod = unit.percent_modifiers.get(ms_key, 0.0)
	unit.percent_modifiers[ms_key] = current_mod - power
