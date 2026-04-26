extends StatusEffect

# Data passed from the ItemEffect OR SkillEffect
var stats_to_buff: Dictionary = {}  
var stats_at_max: Dictionary = {}
var damage_ramp_per_stack: float = 0.0 
var damage_ramp_cap: float = 0.0
var max_stacks_allowed: int = 999
var percent_stats_to_buff: Dictionary = {} #

func on_stat_calculation(unit):
	for key in stats_to_buff:
		var stat_name: String = ""
		
		# 1. If the key is already a String (e.g., "move_speed"), use it!
		if typeof(key) == TYPE_STRING:
			stat_name = key
		# 2. If it's an Enum/Int (e.g., 5), look it up in the STAT_MAP
		elif typeof(key) == TYPE_INT:
			stat_name = Unit.STAT_MAP.get(key, "")
		
		# 3. Apply the stat if we successfully found a name
		if stat_name != "":
			var amount = stats_to_buff[key] * stacks
			unit.modify_stat(stat_name, amount)
		else:
			print("WARNING: Status %s has invalid stat key: %s" % [name, key])
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
