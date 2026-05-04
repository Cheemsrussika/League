extends Node2D
class_name MonsterCamp

# --- CONFIG ---
@export_group("Camp Settings")
@export var respawn_time: float = 10.0
@export var initial_level: int = 1

@export_subgroup("Melee Monsters")
@export var melee_scene: PackedScene
@export var melee_count: int = 2
@export var melee_equipment: Array[ItemData] = [] # NEW: Items added to inventory for STATS
@export var melee_loot: Array[ItemData] = []      # EXISTING: Items that drop on death
@export var melee_chances: Array[float] = []

@export_subgroup("Ranged Monsters")
@export var ranged_scene: PackedScene
@export var ranged_count: int = 1
@export var ranged_equipment: Array[ItemData] = []
@export var ranged_loot: Array[ItemData] = []
@export var ranged_chances: Array[float] = []

@export_subgroup("Siege/Elite Monsters")
@export var siege_scene: PackedScene
@export var siege_count: int = 0
@export var siege_equipment: Array[ItemData] = []
@export var siege_loot: Array[ItemData] = []
@export var siege_chances: Array[float] = []

# --- REFS & STATE ---
@onready var pit_area: Area2D = $PitArea
@onready var timer_label: Label = $RespawnTimerLabel
var spawn_points: Array[Marker2D] = []
var living_monsters: Array = []
var current_camp_level: int = 1
var respawn_timer: float = 0.0
var is_respawning: bool = false

func _ready():
	current_camp_level = initial_level
	if timer_label: timer_label.hide()
	for child in get_children():
		if child is Marker2D:
			spawn_points.append(child)
	spawn_points.sort_custom(func(a, b): return a.name < b.name)
	call_deferred("spawn_camp")

func _process(delta):
	if is_respawning:
		respawn_timer -= delta
		if timer_label:
			var minutes = floor(respawn_timer / 60)
			var seconds = int(respawn_timer) % 60
			timer_label.text = "%01d:%02d" % [minutes, seconds]
		if respawn_timer <= 0:
			spawn_camp()

func spawn_camp():
	is_respawning = false
	if timer_label: timer_label.hide()
	living_monsters.clear()

	var current_point_idx = 0
	
	# Spawn Melee (Passing equipment AND loot)
	for i in range(melee_count):
		_create_monster(melee_scene, melee_equipment, melee_loot, melee_chances, current_point_idx)
		current_point_idx += 1
		
	# Spawn Ranged
	for i in range(ranged_count):
		_create_monster(ranged_scene, ranged_equipment, ranged_loot, ranged_chances, current_point_idx)
		current_point_idx += 1
		
	# Spawn Siege
	for i in range(siege_count):
		_create_monster(siege_scene, siege_equipment, siege_loot, siege_chances, current_point_idx)
		current_point_idx += 1

func _create_monster(scene: PackedScene, equipment: Array, loot: Array, chances: Array, p_idx: int):
	if not scene: return
	
	var monster = scene.instantiate()
	add_child(monster)
	
	# Position
	if p_idx < spawn_points.size():
		monster.position = spawn_points[p_idx].position
	else:
		monster.position = Vector2(randf_range(-50, 50), randf_range(-50, 50))
	
	# 1. LOOT INJECTION (Your original code, untouched)
	if not loot.is_empty():
		monster.set("drop_items", loot.duplicate())
		monster.set("drop_chances", chances.duplicate())
	
	# 2. Init Level Scaling First
	if monster.has_method("initialize_stats"):
		monster.initialize_stats(current_camp_level)

	# 3. EQUIPMENT INJECTION (Add items to inventory -> Calculate Stats -> Stop)
	if not equipment.is_empty():
		var inv = monster.get("inventory")
		if inv != null and inv.has_method("add_item"):
			for item in equipment:
				inv.add_item(item)
			
			if monster.has_method("recalculate_stats"):
				monster.recalculate_stats()
				# Ensure the monster gets the bonus Max HP immediately
				if "current_health" in monster:
					monster.current_health = monster.get_total(Unit.Stat.HP)
					if monster.has_method("_update_health_bar"):
						monster._update_health_bar()

	# Connect and track
	monster.unit_died.connect(_on_monster_died)
	living_monsters.append(monster)

func _on_monster_died(monster_ref):
	if monster_ref in living_monsters:
		living_monsters.erase(monster_ref)
	if living_monsters.size() == 0:
		start_respawn_timer()

func start_respawn_timer():
	is_respawning = true
	respawn_timer = respawn_time
	current_camp_level += 1 
	if timer_label: timer_label.show()

func is_source_allowed(source_unit: Node2D) -> bool:
	if pit_area: return pit_area.overlaps_body(source_unit)
	return global_position.distance_to(source_unit.global_position) <= 450.0

func alert_pack(target: Node, caller: Node):
	for monster in living_monsters:
		if is_instance_valid(monster) and monster != caller:
			if monster.current_state != Monster.State.COMBAT:
				monster.aggro_onto(target)
