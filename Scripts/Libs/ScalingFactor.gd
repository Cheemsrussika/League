extends Resource
class_name ScalingFactor

enum ScaleSource { CASTER, TARGET }
enum ScaleMode { TOTAL, BASE, BONUS, CURRENT, MISSING } # <-- ADDED CURRENT & MISSING

@export var stat: Unit.Stat = Unit.Stat.AD
@export_range(0.0, 10.0, 0.00001) var scale_amount: float = 0.1 
@export var source: ScaleSource = ScaleSource.CASTER
@export var mode: ScaleMode = ScaleMode.TOTAL

@export_group("Limits")
## The maximum amount this specific factor can provide. Set to 0 for Uncapped.
@export var max_value: float = 0.0 

func calculate_value(caster: Unit, target: Unit = null) -> float:
	var unit_to_check = target if source == ScaleSource.TARGET and target else caster
	if not unit_to_check: 
		return 0.0
	
	var raw_stat_value: float = 0.0
	
	match mode:
		ScaleMode.TOTAL:
			raw_stat_value = unit_to_check.get_total(stat)
			
		ScaleMode.BASE:
			var stat_key = Unit.STAT_MAP.get(stat, "")
			raw_stat_value = unit_to_check.base_stats.get(stat_key, 0.0) if stat_key != "" else 0.0
			
		ScaleMode.BONUS:
			var stat_key = Unit.STAT_MAP.get(stat, "")
			raw_stat_value = unit_to_check.bonus_stats.get(stat_key, 0.0) if stat_key != "" else 0.0
			
		ScaleMode.CURRENT:
			# specifically grab current health if HP is selected
			if stat == Unit.Stat.HP:
				raw_stat_value = unit_to_check.current_health
			else:
				raw_stat_value = unit_to_check.get_total(stat) # Fallback just in case
				
		ScaleMode.MISSING:
			# calculate max minus current
			if stat == Unit.Stat.HP:
				var max_hp = unit_to_check.get_total(Unit.Stat.HP)
				raw_stat_value = max_hp - unit_to_check.current_health
			else:
				raw_stat_value = 0.0
				
	var calculated = raw_stat_value * scale_amount
	
	# --- THE CAP LOGIC ---
	if max_value > 0.0:
		return min(calculated, max_value)
		
	return calculated
