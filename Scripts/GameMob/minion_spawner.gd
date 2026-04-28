extends Node2D
class_name MinionSpawner

@export_group("Wave Settings")
@export var spawn_interval: float = 30.0 
@export var spawn_delay: float = 3.0 

@export_group("Melee Configuration")
@export var melee_scene: PackedScene 
@export var melee_count: int = 3
@export var melee_loot: Array[ItemData] = []
@export var melee_chances: Array[float] = []

@export_group("Ranged Configuration")
@export var ranged_scene: PackedScene 
@export var ranged_count: int = 3
@export var ranged_loot: Array[ItemData] = []
@export var ranged_chances: Array[float] = []

@export_group("Siege Configuration")
@export var siege_scene: PackedScene 
@export var siege_count: int = 1
@export var siege_loot: Array[ItemData] = []
@export var siege_chances: Array[float] = []

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
	call_deferred("_on_wave_timeout")

func _on_wave_timeout():
	# We process each category one by one
	await _spawn_category(melee_scene, melee_count, melee_loot, melee_chances)
	await _spawn_category(ranged_scene, ranged_count, ranged_loot, ranged_chances)
	await _spawn_category(siege_scene, siege_count, siege_loot, siege_chances)

# Helper function to handle the loop and timing for each group
func _spawn_category(scene, count, loot, chances):
	if not scene: return
	for i in range(count):
		_spawn_minion(scene, loot, chances)
		await get_tree().create_timer(spawn_delay).timeout
		if not is_instance_valid(self): return

func _spawn_minion(scene_to_spawn: PackedScene, loot: Array, chances: Array):
	if not spawn_point or not scene_to_spawn: return

	var minion = scene_to_spawn.instantiate()
	var random_offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))
	minion.global_position = spawn_point.global_position + random_offset
	minion.team = spawn_team
	
	# Add to tree
	get_tree().current_scene.add_child(minion)

	# --- CATEGORIZED LOOT INJECTION ---
	if not loot.is_empty():
		if loot.size() != chances.size():
			push_error("[MinionSpawner] Loot/Chance mismatch in category for: " + name)
		else:
			if "drop_items" in minion:
				minion.drop_items = loot.duplicate()
			if "drop_chances" in minion:
				minion.drop_chances = chances.duplicate()

	if minion.has_method("set_lane_path"):
		minion.set_lane_path(assigned_path)
