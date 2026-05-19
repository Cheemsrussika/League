extends Camera2D
class_name PlayerCamera

@export_group("Movement")
@export var follow_speed: float = 10.0
@export var is_locked: bool = true

@export_group("Zoom")
@export var min_zoom: float = 1
@export var max_zoom: float = 4.0
@export var zoom_speed: float = 0.1

var target_unit: Node2D = null

func _process(delta: float) -> void:
	# 1. Handle Following/Locking
	if is_locked and target_unit:
		# Smooth interpolation so the camera doesn't "snap" harshly
		global_position = global_position.lerp(target_unit.global_position, follow_speed * delta)
	
	# 2. Key-based Zoom (I/O)
	if Input.is_key_pressed(KEY_I):
		_adjust_zoom(-zoom_speed * delta * 10) # Zoom In
	if Input.is_key_pressed(KEY_O):
		_adjust_zoom(zoom_speed * delta * 10) # Zoom Out

func _input(event: InputEvent) -> void:
	# Mouse Wheel Zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_adjust_zoom(-zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_adjust_zoom(zoom_speed)
	
	# Toggle Lock (Space bar is common for MOBAs)
	if event.is_action_pressed("ui_accept"):
		toggle_lock()

func _adjust_zoom(delta: float) -> void:
	var new_zoom = clamp(zoom.x - delta, min_zoom, max_zoom)
	zoom = Vector2(new_zoom, new_zoom)

func toggle_lock() -> void:
	is_locked = !is_locked
	DevMenu.add_log("Camera Locked: %s" % is_locked)
