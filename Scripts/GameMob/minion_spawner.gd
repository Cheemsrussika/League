extends Node2D
class_name MinionSpawner

@export_group("Wave Settings")
@export var spawn_interval: float = 30.0 
@export var spawn_delay: float = 3.0 

@export_group("Melee Configuration")
@export var melee_scene: PackedScene 
@export var melee_count: int = 3
@export var melee_equipped_items: Array[ItemData] = [] # NEW: Items the minion wears!
@export var melee_loot: Array[ItemData] = []
@export var melee_chances: Array[float] = []

@export_group("Ranged Configuration")
@export var ranged_scene: PackedScene 
@export var ranged_count: int = 3
@export var ranged_equipped_items: Array[ItemData] = [] # NEW
@export var ranged_loot: Array[ItemData] = []
@export var ranged_chances: Array[float] = []

@export_group("Siege Configuration")
@export var siege_scene: PackedScene 
@export var siege_count: int = 1
@export var siege_equipped_items: Array[ItemData] = [] # NEW
@export var siege_loot: Array[ItemData] = []
@export var siege_chances: Array[float] = []

@export_group("Super Configuration") # NEW: Super Minion block!
@export var super_scene: PackedScene 
@export var super_count: int = 0 # Default to 0 until an inhibitor is destroyed!
@export var super_equipped_items: Array[ItemData] = [] 
@export var super_loot: Array[ItemData] = []
@export var super_chances: Array[float] = []

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
	# Pass the new 'equipped_items' array into the helper function
	await _spawn_category(melee_scene, melee_count, melee_equipped_items, melee_loot, melee_chances)
	await _spawn_category(ranged_scene, ranged_count, ranged_equipped_items, ranged_loot, ranged_chances)
	await _spawn_category(siege_scene, siege_count, siege_equipped_items, siege_loot, siege_chances)
	await _spawn_category(super_scene, super_count, super_equipped_items, super_loot, super_chances)

# Updated Helper function
func _spawn_category(scene, count, equipped_items, loot, chances):
	if not scene or count <= 0: return
	for i in range(count):
		_spawn_minion(scene, equipped_items, loot, chances)
		await get_tree().create_timer(spawn_delay).timeout
		if not is_instance_valid(self): return

func _spawn_minion(scene_to_spawn: PackedScene, equipped_items: Array, loot: Array, chances: Array):
	if not spawn_point or not scene_to_spawn: return

	var minion = scene_to_spawn.instantiate()
	var random_offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))
	minion.global_position = spawn_point.global_position + random_offset
	minion.team = spawn_team
	
	# 1. Add to tree (This fires the minion's _ready() function)
	get_tree().current_scene.add_child(minion)

	# --- 2. ACTIVE GEAR INJECTION ---
	if not equipped_items.is_empty() and minion.get("inventory"):
		for item in equipped_items:
			# Assuming your InventoryComponent has an 'items' array. 
			# If you have an 'add_item(item)' function, use that instead!
			minion.inventory.items.append(item.duplicate()) 
			
		# We must wake up the "Silent" system to apply the newly injected gear!
		if minion.has_method("recalculate_stats"):
			minion.recalculate_stats()
			# Ensure health updates to match any new bonus HP the items gave
			minion.current_health = minion.get_total(Unit.Stat.HP) 
			if minion.get("progress_bar"):
				minion.progress_bar.max_value = minion.get_total(Unit.Stat.HP)
				minion.progress_bar.value = minion.current_health

	# --- 3. CATEGORIZED LOOT INJECTION ---
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
