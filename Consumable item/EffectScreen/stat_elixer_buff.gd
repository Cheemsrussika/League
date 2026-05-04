extends Node

var _duration: float
var _target_stat: String
var _flat_amount: float
var _scaling_stat: String
var _scaling_ratio: float
var buff_id: String = ""
var _player: Node

# 1. Declare the timer variable at the top so the whole script can see it!
var _timer: Timer 

func initialize_buff(dur: float, target: String, flat: float, scale_stat: String, scale_ratio: float):
	_duration = dur
	_target_stat = target
	_flat_amount = flat
	_scaling_stat = scale_stat
	_scaling_ratio = scale_ratio

func _ready():
	_player = get_parent().get_parent() 
	
	# Force the unit to update its stats right when the potion is drank
	if is_instance_valid(_player) and _player.has_method("recalculate_stats"):
		_player.recalculate_stats()
	
	# 2. Assign the Timer to our class variable (remove the "var" keyword here)
	_timer = Timer.new()
	add_child(_timer)
	_timer.wait_time = _duration
	_timer.one_shot = true
	_timer.timeout.connect(_on_timeout)
	_timer.start()

# --- YOUR UNIT.GD CALLS THIS AUTOMATICALLY! ---
func on_stat_calculation(unit: Node):
	var bonus = _flat_amount
	
	# Handle scaling (e.g., if the potion gives AD based on Max Health)
	if _scaling_stat != "":
		# We grab the base + bonus stats directly from the unit's dictionaries
		var scale_base = unit.base_stats.get(_scaling_stat, 0.0)
		var scale_bonus = unit.bonus_stats.get(_scaling_stat, 0.0)
		bonus += ((scale_base + scale_bonus) * _scaling_ratio)

	# Use your Unit.gd's native modify_stat function!
	if unit.has_method("modify_stat"):
		unit.modify_stat(_target_stat, bonus)

func _on_timeout():
	# Tell the node to delete itself
	queue_free()
	
	# Force the unit to recalculate stats NOW that this buff is gone
	if is_instance_valid(_player) and _player.has_method("recalculate_stats"):
		# We use call_deferred so it recalculates exactly one frame later, 
		# guaranteeing this node is completely gone from the StatusContainer
		_player.call_deferred("recalculate_stats")

# 3. Update your refresh function to use the class variable
func refresh_duration(new_duration: float) -> void:
	if is_instance_valid(_timer):
		# Calling start() on a running timer will restart it from the beginning with the new time
		_timer.start(new_duration) 
		DevMenu.add_log("Buff duration refreshed to " + str(new_duration) + " seconds!")
