extends Node2D
class_name MinionSpawner

@export_group("Wave Settings")
@export var spawn_interval: float = 30.0 
@export var spawn_delay: float = 3.0 

@export_subgroup("Melee Minions")
@export var melee_scene: PackedScene 
@export var melee_count: int = 3

@export_subgroup("Ranged Minions")
@export var ranged_scene: PackedScene 
@export var ranged_count: int = 3

@export_subgroup("Siege Minions")
@export var Siege_scence: PackedScene 
@export var siege_count: int = 0

@export_group("Routing & Team")
@export var spawn_team: Unit.Team = Unit.Team.BLUE
@export var spawn_point: Marker2D
@export var assigned_path: Path2D 

@onready var wave_timer: Timer = $WaveTimer

func _ready():
	if wave_timer:
		wave_timer.wait_time = spawn_interval
		wave_timer.timeout.connect(_on_wave_timeout)
		wave_timer.start()
		
	# Safely trigger the first wave once the level is loaded
	call_deferred("_on_wave_timeout")

func _on_wave_timeout():
	for i in range(melee_count):
		if melee_scene:
			_spawn_minion(melee_scene)
			await get_tree().create_timer(spawn_delay).timeout
	for i in range(ranged_count):
		if ranged_scene:
			_spawn_minion(ranged_scene)
			await get_tree().create_timer(spawn_delay).timeout
	for i in range(siege_count):
		if Siege_scence:
			_spawn_minion(Siege_scence)
			await  get_tree().create_timer(spawn_delay).timeout

func _spawn_minion(scene_to_spawn: PackedScene):
	if not spawn_point or not scene_to_spawn: return
	
	var minion = scene_to_spawn.instantiate()
	var random_offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))
	minion.global_position = spawn_point.global_position + random_offset
	
	minion.team = spawn_team
	get_tree().current_scene.add_child(minion) 
	
	if minion.has_method("set_lane_path"):
		minion.set_lane_path(assigned_path)
