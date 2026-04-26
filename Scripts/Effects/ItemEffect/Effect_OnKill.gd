extends ItemEffect
class_name EffectKillTracker

@export_group("Threshold Settings")
@export var kills_per_trigger: int = 1
@export var target_must_be_champion: bool = false
## After this many total triggers, the item "completes"
@export var max_triggers: int = 100 

@export_group("Multi-Stat Rewards (Per Kill)")
@export var stats_to_boost: Array[Unit.Stat] = []
@export var reward_scalings: Array[ScalingFactor] = []

@export_group("Completion Rewards (The Payoff)")
## Additional gold given only when max_triggers is reached
@export var payoff_gold: int = 350
## Stats given ONLY when the item is completed (e.g., +10 AD permanent)
@export var stats_at_max: Array[Unit.Stat] = []
@export var scaling_at_max: Array[ScalingFactor] = []

@export_group("Config")
@export var gold_per_kill: int = 1
@export var status_id: String = "kill_tracker_buff"

var _internal_count: int = 0
var total_triggers: int = 0
var is_completed: bool = false
var _accumulated_totals: Dictionary = {} # Index -> Total Stat Value
var _max_payoff_stats: Dictionary = {}   # Index -> One-time bonus

func on_kill(user: Unit, context: Dictionary):
	if is_completed: return # Reap logic: stops once finished
	
	var victim = context.get("victim")
	if not is_instance_valid(victim): return
	if target_must_be_champion and victim.unit_type != Unit.UnitType.CHAMPION:
		return

	_internal_count += 1
	if _internal_count >= kills_per_trigger:
		_internal_count = 0
		total_triggers += 1
		_execute_rewards(user, victim)

func _execute_rewards(user: Unit, victim: Unit):
	# 1. Handle Gold Per Kill (Reap logic)
	if gold_per_kill > 0 and user.has_method("add_gold"):
		user.add_gold(gold_per_kill)

	# 2. Handle Multi-Stat Scaling (The Arrays)
	var loop_size = min(stats_to_boost.size(), reward_scalings.size())
	for i in range(loop_size):
		var gain = reward_scalings[i].calculate_value(user, victim)
		_accumulated_totals[i] = _accumulated_totals.get(i, 0.0) + gain

	# 3. Check for Completion
	if total_triggers >= max_triggers:
		_handle_completion(user, victim)

	_update_status_node(user)

func _handle_completion(user: Unit, victim: Unit):
	is_completed = true
	
	# Give Payoff Gold
	if payoff_gold > 0 and user.has_method("add_gold"):
		user.add_gold(payoff_gold)
	
	# Calculate one-time "At Max" stats
	var payoff_size = min(stats_at_max.size(), scaling_at_max.size())
	for i in range(payoff_size):
		var bonus = scaling_at_max[i].calculate_value(user, victim)
		_max_payoff_stats[i] = bonus

func _update_status_node(user: Unit):
	user.add_status(status_id, 0.0, 1, 1, 0.0)
	var status_node = user.status_container.get_node_or_null(status_id)
	
	if status_node:
		var new_buff_map: Dictionary = {}
		
		# Add the per-kill accumulated stats
		for i in _accumulated_totals.keys():
			var stat_enum = stats_to_boost[i]
			new_buff_map[stat_enum] = _accumulated_totals[i]
			
		# Add the one-time completion stats
		for i in _max_payoff_stats.keys():
			var stat_enum = stats_at_max[i]
			# Add to existing value if it's the same stat, or create new entry
			new_buff_map[stat_enum] = new_buff_map.get(stat_enum, 0.0) + _max_payoff_stats[i]
		
		status_node.stats_to_buff = new_buff_map
		user.recalculate_stats()
		_update_item_ui(user)
