extends Node

var player_champion: Champion 
var selected_unit: Node = null

func start_game(champion_scene: PackedScene, spawn_parent: Node2D, start_position: Vector2):
	var new_hero = champion_scene.instantiate()
	new_hero.global_position = start_position
	spawn_parent.add_child(new_hero)
	
	# Instantiate or find your camera
	var cam = Camera2D.new()
	cam.set_script(load("res://Scripts/PlayerCamera.gd")) # Attach the logic
	cam.enabled = true
	cam.zoom = Vector2(0.5, 0.5)
	
	# Add cam to the scene root (not the hero!)
	spawn_parent.add_child(cam)
	
	# Link the hero to the camera
	cam.target_unit = new_hero
	cam.global_position = start_position # Start at the hero
	
	player_champion = new_hero
	DevMenu.add_log("Game Started with Independent Camera!")
