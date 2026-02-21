extends StatusEffect
class_name StatusAbyssalCurse

func on_stat_calculation(unit:Unit):
	unit.modify_stat("magic_dmg_take__modi", power)
