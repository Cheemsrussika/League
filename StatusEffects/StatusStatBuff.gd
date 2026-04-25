extends StatusEffect

# Data passed from the ItemEffect OR SkillEffect
var stats_to_buff: Dictionary = {}  
var stats_at_max: Dictionary = {}
var damage_ramp_per_stack: float = 0.0 
var damage_ramp_cap: float = 0.0

func on_stat_calculation(unit):
	# --- 1. UNIFIED STAT LOGIC (Items and Skills use this!) ---
	for stat_name in stats_to_buff:
		var amount = stats_to_buff[stat_name] * stacks
		unit.modify_stat(stat_name, amount)

	# --- 2. DAMAGE RAMPING ---
	if damage_ramp_per_stack > 0:
		var total_ramp = stacks * damage_ramp_per_stack
		if damage_ramp_cap > 0:
			total_ramp = min(total_ramp, damage_ramp_cap)
		unit.modify_stat("dmg_dealt_modifier", total_ramp)

	# --- 3. AT MAX STACKS ---
	if stacks >= max_stacks:
		for stat_name in stats_at_max:
			unit.modify_stat(stat_name, stats_at_max[stat_name])
