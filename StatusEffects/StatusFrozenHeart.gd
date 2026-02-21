extends StatusEffect
class_name StatusFrozenHeart

func on_stat_calculation(unit):
	# Reduces AS by the power (0.20)
	unit.modify_stat("attack_speed", -power)
