extends ChampionPassive
class_name PassiveConqueror

@export var STATUS_ID = "conqueror_buff"
@export var MAX_STACKS = 10
@export var DURATION = 5.0 # Seconds before stacks fall off

func on_combat_event(event_name: String, context: Dictionary, champion: Node) -> void:
	if event_name == "on_damage_dealt":
		# Ignore proc/item damage loops
		if context.get("category") == "proc": return
		
		# Filter: Only trigger on basic attacks or spells
		var category = context.get("category", "")
		if category != "attack" and category != "spell": return
		
		# 1. Apply or refresh the status effect node
		champion.apply_status_effect(STATUS_ID, DURATION, 1, 1.0, champion)
		var status = champion.status_container.get_node_or_null(STATUS_ID)
		
		if status:
			status.max_stacks = MAX_STACKS
			
			# 2. Adaptive Force: Buff whichever stat is currently higher
			if champion.get_total(champion.Stat.AP) > champion.get_total(champion.Stat.AD):
				status.stats_to_buff = {"ability_power": 3.0} # +3 AP per stack
			else:
				status.stats_to_buff = {"attack_damage": 2.0} # +2 AD per stack
				
			# 3. Capstone Reward: Grant Omnivamp at max stacks
			if status.stacks >= MAX_STACKS:
				status.stats_at_max = {"omnivamp": 8.0} # +8% Omnivamp at full stacks
			else:
				status.stats_at_max = {}
				
			# 4. Force the engine to update values
			champion.recalculate_stats()
