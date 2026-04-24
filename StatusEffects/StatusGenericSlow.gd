extends StatusEffect

func on_apply(unit):
	type = "slow"
func on_stat_calculation(unit):
	unit.is_slowed = true
	unit.move_speed_modifier = unit.move_speed_modifier * (1.0 - power)
