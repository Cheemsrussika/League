extends Node

var player_champion: Champion 


func start_game(champion_scene: PackedScene, spawn_parent: Node2D, start_position: Vector2):
	var new_hero = champion_scene.instantiate()
	new_hero.global_position = start_position

	
	var cam = Camera2D.new()
	cam.enabled = true
	cam.set_zoom(Vector2(0.5,0.5))
	new_hero.add_child(cam)
	spawn_parent.add_child(new_hero)

	player_champion = new_hero
	print("Game Started! Player spawned at ", start_position)
