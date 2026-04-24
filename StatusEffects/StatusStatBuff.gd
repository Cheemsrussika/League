extends StatusEffect

# Data passed from the ItemEffect
var stats_to_buff: Dictionary = {}  
var stats_at_max: Dictionary = {}
var damage_ramp_per_stack: float = 0.0 
var damage_ramp_cap: float = 0.0

func on_stat_calculation(unit):
	# --- 1. ITEM LOGIC (Dictionaries) ---
	for stat_name in stats_to_buff:
		var amount = stats_to_buff[stat_name] * stacks
		unit.modify_stat(stat_name, amount)

	# --- 2. SKILL LOGIC (Fall-back for simple buffs like Garen Q) ---
	# We check if 'power' was injected and if we are a known stat status (like 'skill_speed')
	if "power" in self and self.power > 0:
		if name.contains("speed") or name.contains("haste"):
			unit.modify_stat("move_speed", self.power) # or whatever your MS string is
		elif name.contains("attack_speed"):
			unit.modify_stat("attack_speed", self.power)

	# --- 3. DAMAGE RAMPING ---
	if damage_ramp_per_stack > 0:
		var total_ramp = stacks * damage_ramp_per_stack
		if damage_ramp_cap > 0:
			total_ramp = min(total_ramp, damage_ramp_cap)
		unit.modify_stat("dmg_dealt_modifier", total_ramp)

	# --- 4. AT MAX STACKS ---
	if stacks >= max_stacks:
		for stat_name in stats_at_max:
			unit.modify_stat(stat_name, stats_at_max[stat_name])
