extends Area2D

@export_file("*.tscn") var next_map_path: String
@export var spawn_marker_name: String = "SpawnPoint_WestDoor"

func _on_body_entered(body):
	if body == GameManager.player_champion:
		SaveManager.save_game("autosave") 
		GameManager.target_spawn_node_name = spawn_marker_name
		
		# THE FIX: Tell Godot to wait until physics are done before changing!
		get_tree().call_deferred("change_scene_to_file", next_map_path)
