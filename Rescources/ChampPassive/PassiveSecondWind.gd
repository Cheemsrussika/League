extends ChampionPassive
class_name PassiveSecondWind

const STATUS_ID = "second_wind_buff"
const DURATION = 3.0

func on_combat_event(event_name: String, context: Dictionary, champion: Node) -> void:
	if event_name == "on_hit_received":
		# Make sure we actually lost health (ignore fully shielded/blocked damage)
		var health_lost = context.get("health_lost", 0.0)
		if health_lost <= 0: return
		
		# 1. Refresh or apply the regeneration buff
		champion.apply_status_effect(STATUS_ID, DURATION, 1, 1.0, champion)
		var status = champion.status_container.get_node_or_null(STATUS_ID)
		
		if status:
			status.max_stacks = 1 # Does not stack intensity, only resets duration
			
			# 2. Calculate Missing Health percentage
			var max_hp = champion.get_total(champion.Stat.HP)
			var missing_hp = max_hp - champion.current_health
			
			# Math: Flat 4 HP/sec + 4% of your missing health pool
			var calculated_regen = 4.0 + (missing_hp * 0.04)
			
			# 3. Assign to the status (Assuming your engine handles a "health_regeneration" stat)
			status.stats_to_buff = {"health_regeneration": calculated_regen}
			
			champion.recalculate_stats()
