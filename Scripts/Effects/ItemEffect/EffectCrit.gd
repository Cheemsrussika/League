extends ItemEffect
class_name EffectCritModifier

# --- CONFIGURATION ---
@export_category("Critical Stats Logic")

# MODE 1: Static Bonus (Like Infinity Edge)
@export_group("Static Bonus")
@export var flat_crit_damage_bonus: float = 0.0 # e.g., 0.35 for +35% Crit Dmg
@export var crit_chance_multiplier: float = 1.0 # e.g., 2.0 to Double Crit Chance (Yasuo)

# MODE 2: Overcrit Conversion (Like Yasuo/Yone Overflow)
@export_group("Overcrit Conversion")
@export var enable_overcrit: bool = false
@export var conversion_rate: float = 0.5 # 1% Excess Crit = 0.5% Crit Dmg

func on_stat_calculation(unit):
	# --- 1. HANDLE CRIT CHANCE MULTIPLIER (e.g. Yasuo Double Crit) ---
	if crit_chance_multiplier != 1.0:
		# We assume "flat_crit_chance_mult" is a key your stat system looks for
		_safe_add(unit, "flat_crit_chance_mult", crit_chance_multiplier - 1.0)

	# --- 2. CALCULATE CRIT DAMAGE BONUS ---
	var final_crit_dmg_bonus = flat_crit_damage_bonus
	
	# --- 3. HANDLE OVERCRIT LOGIC ---
	if enable_overcrit:
		# CAUTION: We use base + bonus to avoid infinite loops with get_total
		# If your get_total(Stat.CRIT) is safe, you can use that instead.
		var current_crit = unit.get_total(unit.Stat.CRIT)
		# If we have a multiplier (like Yasuo), the current_crit might not reflect it yet 
		# depending on your calculation order. 
		# Ideally, use the raw numbers:
		# current_crit = (unit.base_stats.get("crit", 0) + unit.bonus_stats.get("crit", 0)) * crit_chance_multiplier
		if current_crit > 100.0:
			var overflow = current_crit - 100.0
			final_crit_dmg_bonus += (overflow * conversion_rate)
	# --- 4. APPLY TO UNIT ---
	if final_crit_dmg_bonus > 0:
		# We use a unique key for this item so it doesn't overwrite other items
		# Or, if your system sums up "flat_crit_damage_bonus", use +=
		_safe_add(unit, "flat_crit_damage_bonus", final_crit_dmg_bonus)

# Helper to safely add to modifiers without crashing if key is missing
func _safe_add(unit, key: String, value: float):
	if unit.stat_modifiers.has(key):
		unit.stat_modifiers[key] += value
	else:
		unit.stat_modifiers[key] = value
