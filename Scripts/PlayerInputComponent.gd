extends Node
class_name PlayerInputComponent

@export var champion: Champion 

func _ready():
	if not champion and get_parent() is Champion:
		champion = get_parent()

func _physics_process(delta):
	if not is_instance_valid(champion) or champion.is_dead: return
	champion.execute_combat_logic(delta)

func _unhandled_input(event):
	if not is_instance_valid(champion) or champion.is_dead: return
	
	# --- MOUSE INPUT ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var target_enemy = _get_target_under_mouse()
		
		if target_enemy:
			if "team" in target_enemy and target_enemy.team == champion.team:
				# Ally clicked? usually move to them or follow
				champion.current_target = null
				champion.nav_target = target_enemy.global_position
			else:
				# Enemy clicked -> Attack
				champion.current_target = target_enemy
				champion.nav_target = null 
		else:
			# Ground clicked -> Move
			champion.nav_target = champion.get_global_mouse_position()
			champion.current_target = null

			if champion.is_winding_up:
				champion.is_winding_up = false

	# --- KEYBOARD INPUT ---
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_S:
				champion.nav_target = null
				champion.current_target = null
				champion.is_winding_up = false
				champion.velocity = Vector2.ZERO
			
			# Add Skill calls here later:
			# KEY_Q: champion.cast_skill("Q")

# --- HELPER ---
func _get_target_under_mouse() -> Node2D:
	var space = champion.get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	
	query.position = champion.get_global_mouse_position()
	query.collide_with_areas = true 
	query.collide_with_bodies = true
	query.collision_mask = 4
	
	var results = space.intersect_point(query)
	for result in results:
		var collider = result.collider
		var actual_unit = collider
		if collider is Area2D:
			actual_unit = collider.get_parent()
			
		if actual_unit == champion: continue
		
		if actual_unit is Unit and not actual_unit.is_dead:
			return actual_unit
			
	return null
