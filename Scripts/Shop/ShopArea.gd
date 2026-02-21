extends Area2D

func _on_body_exited(body):
	if body.is_in_group("player"):
		var shop_ui = get_tree().get_first_node_in_group("shop_ui")
		if shop_ui:
			shop_ui.visible = false 
