# ShopTrigger.gd (Attached to an NPC or Shop Area)
extends Area2D

@export var shop_scene: PackedScene

func _input(event):
	if event.is_action_pressed("interact") and overlaps_body(get_tree().get_first_node_in_group("player")):
		open_shop()

func open_shop():
	# Instantiate the screen
	var shop_instance = shop_scene.instantiate()
	
	# Add it to the main UI layer
	get_tree().root.add_child(shop_instance)
	
	# Optional: Pause the game world
	get_tree().paused = true
