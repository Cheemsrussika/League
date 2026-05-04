extends ItemEffect
class_name ElixirEffect

@export var buff_scene: PackedScene

func on_consume(owner_node: Node) -> void:
	if buff_scene and owner_node.has_node("StatusContainer"):
		var buff_instance = buff_scene.instantiate()
		# Add it directly into your StatusContainer!
		owner_node.get_node("StatusContainer").add_child(buff_instance)
