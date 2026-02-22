extends Node
class_name MinionAIComponent

enum State { ADVANCING, CHASING, ATTACKING, RETURNING, IDLE }
var current_state: State = State.ADVANCING

enum BehaviorMode { FOLLOW_PATH, WANDER, STAND_STILL }
@export var mode: BehaviorMode = BehaviorMode.FOLLOW_PATH

@export_group("AI Settings")
@export var aggro_range: float = 500.0
@export var max_chase_distance: float = 500.0 # The "Leash"
@export var path_return_threshold: float = 50.0 # How close it needs to get to the path to resume advancing

var lane_path: Path2D = null
var path_points: PackedVector2Array = []
var current_path_index: int = 0

var parent_unit: Unit = null
var current_target: Unit = null

func _ready():
	parent_unit = get_parent() as Unit
	if GameEvents:
		GameEvents.unit_damaged.connect(_on_global_unit_damaged)
		
	if mode == BehaviorMode.STAND_STILL:
		current_state = State.IDLE

func set_lane_path(path: Path2D):
	lane_path = path
	if lane_path and lane_path.curve:
		# Get all the waypoints of the path
		path_points = lane_path.curve.get_baked_points()
		# Transform points to global coordinates
		for i in range(path_points.size()):
			path_points[i] = lane_path.to_global(path_points[i])
			
		current_path_index = _get_closest_path_index(parent_unit.global_position)

func _physics_process(delta: float):
	if not parent_unit or parent_unit.is_dead:
		return

	match current_state:
		State.ADVANCING:
			_process_advancing(delta)
		State.CHASING:
			_process_chasing(delta)
		State.ATTACKING:
			_process_attacking(delta)
		State.RETURNING:
			_process_returning(delta)

# --- STATE LOGIC ---

func _process_advancing(delta: float):
	if mode != BehaviorMode.FOLLOW_PATH or path_points.is_empty(): return
	
	# 1. Look for enemies
	var best_target = _find_best_target()
	if is_instance_valid(best_target):
		current_target = best_target
		_change_state(State.CHASING)
		return
		
	# 2. If no enemies, walk down the path
	var target_pos = path_points[current_path_index]
	_move_towards(target_pos)
	
	# 3. Advance to the next waypoint if we reached this one
	if parent_unit.global_position.distance_to(target_pos) < 20.0:
		current_path_index = min(current_path_index + 1, path_points.size() - 1)

func _process_chasing(delta: float):
	# 1. Validate Target
	if not is_instance_valid(current_target) or current_target.is_dead:
		current_target = null
		_change_state(State.RETURNING)
		return
		
	# 2. Check the Leash! Are we too far from the lane?
	if lane_path:
		var closest_path_point = lane_path.curve.get_closest_point(lane_path.to_local(parent_unit.global_position))
		closest_path_point = lane_path.to_global(closest_path_point)
		
		if parent_unit.global_position.distance_to(closest_path_point) > max_chase_distance:
			current_target = null # Drop Aggro
			_change_state(State.RETURNING)
			return

	# 3. Check if in Attack Range
	var attack_range = parent_unit.get_total(Unit.Stat.RANGE)
	if parent_unit.global_position.distance_to(current_target.global_position) <= attack_range:
		_change_state(State.ATTACKING)
	else:
		# Move to target
		_move_towards(current_target.global_position)

func _process_attacking(delta: float):
	if not is_instance_valid(current_target) or current_target.is_dead:
		current_target = null
		_change_state(State.RETURNING)
		return
		
	var attack_range = parent_unit.get_total(Unit.Stat.RANGE)
	var distance_to_target = parent_unit.global_position.distance_to(current_target.global_position)
	
	if distance_to_target > attack_range:
		# Target ran away, chase them!
		_change_state(State.CHASING)
		return
		
	# STOP moving and attack (Assuming your parent_unit has an attack target variable)
	parent_unit.velocity = Vector2.ZERO
	parent_unit.move_and_slide()
	parent_unit.current_target = current_target 
	# The parent_unit script should handle the actual cooldown/projectile firing

func _process_returning(delta: float):
	if not lane_path:
		_change_state(State.ADVANCING)
		return
		
	# Ignore enemies, just walk back to the closest point on the path
	current_path_index = _get_closest_path_index(parent_unit.global_position)
	var return_pos = path_points[current_path_index]
	
	_move_towards(return_pos)
	
	if parent_unit.global_position.distance_to(return_pos) <= path_return_threshold:
		_change_state(State.ADVANCING)

# --- TARGETING & MOVEMENT HELPERS ---

func _find_best_target() -> Unit:
	var all_units = get_tree().get_nodes_in_group("unit")
	var valid_targets = []
	
	for u in all_units:
		if u is Unit and not u.is_dead:
			if u.team != parent_unit.team and u.team != Unit.Team.NEUTRAL:
				if parent_unit.global_position.distance_to(u.global_position) <= aggro_range:
					valid_targets.append(u)
				
	if valid_targets.is_empty(): return null
	valid_targets.sort_custom(func(a, b): 
		return parent_unit.global_position.distance_to(a.global_position) < parent_unit.global_position.distance_to(b.global_position)
	)
	for target in valid_targets:
		if target.unit_type == Unit.UnitType.MINION:
			return target
	return valid_targets[0]

func _on_global_unit_damaged(victim: Unit, attacker: Unit, amount: float):
	# THE CALL FOR HELP MECHANIC
	if not is_instance_valid(victim) or not is_instance_valid(attacker) or not is_instance_valid(parent_unit): return
	if current_state == State.RETURNING: return 
	if victim.team == parent_unit.team and victim.unit_type == Unit.UnitType.CHAMPION:
		if attacker.team != parent_unit.team and attacker.unit_type == Unit.UnitType.CHAMPION:
			if parent_unit.global_position.distance_to(attacker.global_position) <= aggro_range:
				current_target = attacker
				_change_state(State.CHASING)
func _move_towards(target_pos: Vector2):
	var direction = (target_pos - parent_unit.global_position).normalized()
	var speed = parent_unit.get_total(Unit.Stat.MS) # Movement Speed
	parent_unit.velocity = direction * speed
	parent_unit.move_and_slide()

func _change_state(new_state: State):
	current_state = new_state

func _get_closest_path_index(pos: Vector2) -> int:
	if path_points.is_empty(): return 0
	var closest_idx = 0
	var min_dist = pos.distance_to(path_points[0])
	for i in range(1, path_points.size()):
		var dist = pos.distance_to(path_points[i])
		if dist < min_dist:
			min_dist = dist
			closest_idx = i
	return closest_idx
