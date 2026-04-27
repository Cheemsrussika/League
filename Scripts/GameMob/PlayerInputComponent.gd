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
	if champion.is_dashing:
		if not champion.can_cancel_dash:
			# UNSTOPPABLE: Ignore all inputs (Q, W, E, R, Right-Click)
			return 
		else:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				champion.stop_movement()
			else:
				return
	# --- MOUSE INPUT (Movement/Attacking) ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		champion.stop_movement()
		var target_enemy = _get_target_under_mouse()
		
		if target_enemy:
			if "team" in target_enemy and target_enemy.team == champion.team:
				champion.current_target = null
				champion.nav_target = target_enemy.global_position
			else:
				champion.current_target = target_enemy
				champion.nav_target = null 
		else:
			champion.nav_target = champion.get_global_mouse_position()
			champion.current_target = null

			if champion.is_winding_up:
				champion.is_winding_up = false
				
	# --- SKILL INPUT ---
	# 1. Package the data the skill needs before casting
	@warning_ignore("unused_variable")
	var target_data = {
		"target_position": champion.get_global_mouse_position(),
		"target_unit": _get_target_under_mouse()
	}
	
	# 2. Access the skill slots via the champion reference
	if event.is_action_pressed("q"):
		_handle_skill_cast(champion.skill_q)
	elif event.is_action_pressed("w"):
		_handle_skill_cast(champion.skill_w)
	elif event.is_action_pressed("e"):
		_handle_skill_cast(champion.skill_e)
	elif event.is_action_pressed("r"):
		_handle_skill_cast(champion.skill_r)
	elif event.is_action_pressed("g"):
		_handle_skill_cast(champion.skill_g)
	elif event.is_action_pressed("f"):
		_handle_skill_cast(champion.skill_f)

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
# Inside your Input Handler script

func _handle_skill_cast(slot: SkillSlot):
	if not slot or not slot.skill_data: return
	
	var data = slot.skill_data
	var found_unit = null
	
	# 1. Determine the search filter based on the new booleans
	# If the skill can hit both, we search for "ANY"
	var filter = "NONE"
	if data.target_enemies and data.target_allies:
		filter = "ANY"
	elif data.target_enemies:
		filter = "ENEMY"
	elif data.target_allies:
		filter = "ALLY"
	# Note: target_self is handled separately in step 3
	
	# 2. Try to find a unit under the mouse
	if filter != "NONE":
		found_unit = _get_target_under_mouse(filter)
	
	# 3. Handle Range & Chasing
	if found_unit:
		var distance = champion.global_position.distance_to(found_unit.global_position)
		if data.cast_range > 0 and distance > data.cast_range:
			DevMenu.add_log("Out of Range! Moving to target.")
			champion.set_chase_and_cast(found_unit, slot)
			return 

	# 4. Finalize target_data
	# If we didn't click anyone, but 'target_self' is on, treat caster as target
	if found_unit == null and data.target_self:
		found_unit = champion

	var target_data = {
		"target_position": champion.get_global_mouse_position(),
		"target_unit": found_unit
	}
	
	# 5. Activate the Slot
	slot.activate(champion, target_data)
	
	# Trigger event for costs/animations
	var lvl_idx = clamp(slot.current_level - 1, 0, data.resource_cost.size() - 1)
	var actual_cost = data.resource_cost[lvl_idx]
	champion.on_skill_cast(data.skill_name, actual_cost, false)
	
func _get_target_under_mouse(filter_type: String = "ANY") -> Node2D:
	var space = champion.get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	
	query.position = champion.get_global_mouse_position()
	query.collide_with_areas = true 
	query.collide_with_bodies = true
	query.collision_mask = 4
	
	var results = space.intersect_point(query)
	for result in results:
		var actual_unit = result.collider
		if actual_unit is Area2D: actual_unit = actual_unit.get_parent()
		if actual_unit == champion and not filter_type == "ANY": continue	
		if not actual_unit is Unit or actual_unit.is_dead: continue

		# --- TEAM FILTERING ---
		match filter_type:
			"ENEMY":
				if actual_unit.team != champion.team:
					return actual_unit
			"ALLY":
				if actual_unit.team == champion.team:
					return actual_unit
			"ANY":
				return actual_unit
			
	return null
