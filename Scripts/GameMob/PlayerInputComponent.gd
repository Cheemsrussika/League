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
	
	# --- MOUSE INPUT (Movement/Attacking) ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
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
func _handle_skill_cast(slot: SkillSlot):
	if not slot or not slot.skill_data: return
	
	# 1. Ask the SkillData what it wants to target
	var filter = "ANY"
	match slot.skill_data.targeting:
		slot.skill_data.TargetType.ENEMY: filter = "ENEMY"
		slot.skill_data.TargetType.ALLY:  filter = "ALLY"
		slot.skill_data.TargetType.ANY:   filter = "ANY"
		slot.skill_data.TargetType.SELF_ONLY: filter = "NONE" # Mouse ignored

	# 2. Get the target based on that filter
	var found_unit = null
	if filter != "NONE":
		found_unit = _get_target_under_mouse(filter)
	if found_unit:
		var distance = champion.global_position.distance_to(found_unit.global_position)
		
		# Check if the skill has a range limit
		if slot.skill_data.cast_range > 0:
			if distance > slot.skill_data.cast_range:
				print("Out of Range! Moving to target.")
				# Tell the champion to chase the target and cast when close
				champion.set_chase_and_cast(found_unit, slot)
				return # Don't activate yet!

	# If we are in range or it's a self-cast
	var target_data = {
		"target_position": champion.get_global_mouse_position(),
		"target_unit": found_unit
	}
	slot.activate(champion, target_data)
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
		
		if actual_unit == champion: continue
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
