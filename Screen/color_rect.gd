extends ColorRect


# Called when the node enters the scene tree for the first time.
# Attach this to the ColorRect instead
func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			get_parent().dragging = true # Tell the Panel to start moving
			get_parent().drag_offset = get_global_mouse_position() - get_parent().global_position
		else:
			get_parent().dragging = false
