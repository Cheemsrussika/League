extends Node2D
class_name MonsterCamp

# --- CONFIG ---
@export_group("Camp Settings")
# The monsters to spawn (e.g. [Wolf, Wolf, Alpha])
@export var camp_roster: Array[PackedScene] = [] 
@export var respawn_time: float = 10.0
@export var initial_level: int = 1

# --- REFS ---
@onready var pit_area: Area2D = $PitArea
@onready var timer_label: Label = $RespawnTimerLabel
# We will find all Marker2D children automatically
var spawn_points: Array[Marker2D] = []

# --- STATE ---
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
			
	# sort them by name so "Pos1" always comes before "Pos2"
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
	if camp_roster.is_empty(): return

	is_respawning = false
	if timer_label: timer_label.hide()
	living_monsters.clear()
	
	# 2. SPAWN LOOP
	for i in range(camp_roster.size()):
		var monster_scene = camp_roster[i]
		if not monster_scene: continue
		
		var new_monster = monster_scene.instantiate()
		add_child(new_monster)
		
		# 3. ASSIGN POSITION
		# If we have a marker for this index, use it. Otherwise default to (0,0)
		if i < spawn_points.size():
			new_monster.position = spawn_points[i].position
		else:
			# Fallback if you have more monsters than markers
			new_monster.position = Vector2(randf_range(-50, 50), randf_range(-50, 50))
			
		# Initialize
		if new_monster.has_method("initialize_stats"):
			new_monster.initialize_stats(current_camp_level)
		
		if new_monster.has_signal("unit_died"):
			new_monster.connect("unit_died", _on_monster_died)
			
		living_monsters.append(new_monster)

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

func alert_pack(target_unit, caller_monster):
	for monster in living_monsters:
		if is_instance_valid(monster) and monster != caller_monster:
			if monster.current_state != Monster.State.COMBAT:
				monster.aggro_onto(target_unit)

func is_source_allowed(source_unit: Node2D) -> bool:
	if pit_area: return pit_area.overlaps_body(source_unit)
	return global_position.distance_to(source_unit.global_position) <= 450.0
