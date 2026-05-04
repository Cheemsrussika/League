extends Node
class_name PlayerInputComponent

@export var champion: Champion 

func _ready():
	if not champion and get_parent() is Champion:
		champion = get_parent()

func _physics_process(delta):
	if not is_instance_valid(champion) or champion.is_dead: return
	
	# --- WASD MOVEMENT ---
	# We only process keyboard movement if the player isn't locked in an animation/dash
	if not champion.is_dashing and not champion.is_winding_up and not champion.pending_skill_slot:
		# NOTE: You will need to set these 4 actions in your Project Settings -> Input Map
		var input_dir = Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_up", "move_down")
		).normalized()
		
		if input_dir != Vector2.ZERO:
			champion.velocity = input_dir * champion.get_current_move_speed()
		else:
			# Apply friction to stop when keys are released
			champion.velocity = champion.velocity.move_toward(Vector2.ZERO, 2000 * delta)
	# ---------------------------------------------------------
	# --- NEW: CONTINUOUS "HOLD-TO-ATTACK" LOGIC ---
	# ---------------------------------------------------------
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if champion.auto_attack_slot and champion.auto_attack_slot.skill_data:
			
			# The game checks this every frame, but the combo will 
			# ONLY advance when the Attack Speed cooldown finishes!
			if champion.auto_attack_slot.is_ready():
				champion.stop_movement()
				champion.current_target = null 
				
				if champion.is_winding_up: 
					champion.is_winding_up = false
				
				_handle_skill_cast(champion.auto_attack_slot)
				
				# Advance to the next attack in the combo!
				champion.advance_combo()
	# Execute combat processing (which now just handles dashing, winding up, and move_and_slide)
	champion.execute_combat_logic(delta)


func _unhandled_input(event):
	if not is_instance_valid(champion) or champion.is_dead: return
	if champion.is_dashing:
		if not champion.can_cancel_dash:
			# UNSTOPPABLE: Ignore all inputs
			return 
		else:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				champion.stop_movement()
	
	# --- MOUSE INPUT (Attacking/Selecting) ---
			
	# 2. LEFT-CLICK: Unit Selection ONLY (Movement removed)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var clicked_unit = _get_target_under_mouse("ANY")
		if clicked_unit:
			# GameManager.selected_unit = clicked_unit 
			DevMenu.add_log("Selected unit: " + clicked_unit.name)
			
	# --- SKILL INPUT ---
	@warning_ignore("unused_variable")
	var target_data = {
		"target_position": champion.get_global_mouse_position(),
		"target_unit": _get_target_under_mouse()
	}
	
	if event.is_action_pressed("skill1"): _handle_skill_cast(champion.skill_q)
	elif event.is_action_pressed("skill2"): _handle_skill_cast(champion.skill_t)
	elif event.is_action_pressed("skill3"): _handle_skill_cast(champion.skill_e)
	elif event.is_action_pressed("skill4"): _handle_skill_cast(champion.skill_r)
	elif event.is_action_pressed("skill5"): _handle_skill_cast(champion.skill_h)


# --- HELPER ---
func _handle_skill_cast(slot: SkillSlot):
	if not slot or not slot.skill_data: return
	
	var data = slot.skill_data
	var found_unit = null
	
	var filter = "NONE"
	if data.target_enemies and data.target_allies: filter = "ANY"
	elif data.target_enemies: filter = "ENEMY"
	elif data.target_allies: filter = "ALLY"
	
	if filter != "NONE":
		found_unit = _get_target_under_mouse(filter)
	

	if found_unit:
		var distance = champion.global_position.distance_to(found_unit.global_position)
		var current_cast_range = data.cast_range
		if data.is_auto_attack:
			current_cast_range = champion.get_total_stat(Unit.Stat.RANGE)
			
		if current_cast_range > 0 and distance > current_cast_range:
			DevMenu.add_log("Out of Range! Moving to target.")
			champion.set_chase_and_cast(found_unit, slot)
			return

	if found_unit == null and data.target_self:
		found_unit = champion

	var target_data = {
		"target_position": champion.get_global_mouse_position(),
		"target_unit": found_unit
	}
	
	slot.activate(champion, target_data)
	
	var lvl_idx = clamp(slot.current_level - 1, 0, data.resource_cost.size() - 1)
	var actual_cost = data.resource_cost[lvl_idx]
	champion.on_skill_cast(data.skill_name, actual_cost, false)
	
func _get_target_under_mouse(filter_type: String = "ANY") -> Node2D:
	var space = champion.get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	
	query.position = champion.get_global_mouse_position()
	query.collide_with_areas = true 
	query.collide_with_bodies = true
	query.collision_mask = 4 + 8 + 16
	
	var results = space.intersect_point(query)
	for result in results:
		var actual_unit = result.collider
		if actual_unit is Area2D: actual_unit = actual_unit.get_parent()
		if actual_unit == champion and not filter_type == "ANY": continue    
		if not actual_unit is Unit or actual_unit.is_dead: continue

		match filter_type:
			"ENEMY":
				if actual_unit.team != champion.team: return actual_unit
			"ALLY":
				if actual_unit.team == champion.team: return actual_unit
			"ANY":
				return actual_unit
			
	return null
