@tool # This allows it to run inside the Godot Editor
extends Node2D

@export var grid_size: int = 64
@export var line_width: float = 1.0
@export var grid_color: Color = Color(1, 1, 1, 0.1) # Soft white
@export var secondary_color: Color = Color(0.5, 0.5, 0.5, 0.05) # Subtle grey
@export var show_grid: bool = true:
	set(val):
		show_grid = val
		queue_redraw()

func _draw():
	if not show_grid: return
	
	# We draw a massive area (adjust these numbers to your world size)
	var limit = 5000 
	
	# Draw Vertical Lines
	for x in range(-limit, limit, grid_size):
		var color = grid_color if (x / grid_size) % 2 == 0 else secondary_color
		draw_line(Vector2(x, -limit), Vector2(x, limit), color, line_width)
		
	# Draw Horizontal Lines
	for y in range(-limit, limit, grid_size):
		var color = grid_color if (y / grid_size) % 2 == 0 else secondary_color
		draw_line(Vector2(-limit, y), Vector2(limit, y), color, line_width)

# Helper to help you calculate range in code
func get_grid_pos(world_pos: Vector2) -> Vector2:
	return (world_pos / grid_size).floor()
