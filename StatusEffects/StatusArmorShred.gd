extends StatusEffect
class_name StatusArmorShred

# Config
var shred_percent_per_stack: float = 0.05 # 5% per stack
var max_stacks_allowed: int = 6

func on_apply(unit):
	# Setup flags for the UI/System
	type = "shred" 
	
	# Sync the generic 'max_stacks' variable from the parent class
	# with the specific variable used here
	max_stacks = max_stacks_allowed

func on_stat_calculation(unit):
	var total_shred = stacks * shred_percent_per_stack
	
	unit.modify_stat("armor_reduction_percent", total_shred)
