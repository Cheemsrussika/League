extends Node

var player_champion: Node2D 
var selected_unit: Node = null
var ui_scene = preload("res://Screen/MainUI.tscn") # Update this path if needed!
var current_ui: CanvasLayer = null
# NEW: The door will change this before the map loads
var target_spawn_node_name: String = "" 

func start_game(champion_scene: PackedScene, spawn_parent: Node2D, fallback_position: Vector2):
	var new_hero = champion_scene.instantiate()
	
	# 1. FIGURE OUT WHERE TO SPAWN
	var final_pos = fallback_position
	
	# If we came through a door, look for the spawn marker!
	if target_spawn_node_name != "":
		var marker = spawn_parent.get_node_or_null(target_spawn_node_name)
		if marker:
			final_pos = marker.global_position
			
		target_spawn_node_name = "" # Reset it so we don't accidentally use it again later!
		
	new_hero.global_position = final_pos
	spawn_parent.add_child(new_hero)
	
	# 2. CAMERA SETUP (Your code remains the same)
	var cam = Camera2D.new()
	cam.set_script(load("res://Scripts/PlayerCamera.gd")) 
	cam.enabled = true
	cam.zoom = Vector2(0.5, 0.5)
	spawn_parent.add_child(cam)
	cam.target_unit = new_hero
	cam.global_position = final_pos 
	
	var new_ui = ui_scene.instantiate()
	spawn_parent.add_child(new_ui)
	current_ui = new_ui 
	
	
	
	


	player_champion = new_hero
	
	SaveManager.load_game("slot_1")
	DevMenu.add_log("Player spawned at " + str(final_pos))
