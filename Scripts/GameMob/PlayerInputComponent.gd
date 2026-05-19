extends Node
class_name PlayerInputComponent

@export var champion: Champion 
var last_facing: String = "down"
func _ready():
	if not champion and get_parent() is Champion:
		champion = get_parent()

func _physics_process(delta):
	if not is_instance_valid(champion) or champion.is_dead: return
	
	# --- WASD MOVEMENT ---
	if not champion.is_dashing and not champion.is_winding_up and not champion.pending_skill_slot:
		var input_dir = Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_up", "move_down")
		).normalized()
		
		if input_dir != Vector2.ZERO:
			champion.velocity = input_dir * champion.get_current_move_speed()
			# NEW: Tell the body to walk!
			update_movement_anim(input_dir, true)
		else:
			champion.velocity = champion.velocity.move_toward(Vector2.ZERO, 2000 * delta)
			# NEW: Tell the body to idle!
			update_movement_anim(Vector2.ZERO, false)
			
	# --- NEW: CONTINUOUS "HOLD-TO-ATTACK" LOGIC ---
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if champion.auto_attack_slot and champion.auto_attack_slot.skill_data:
			if champion.auto_attack_slot.is_ready():
				champion.stop_movement()
				champion.current_target = null 
				
				if champion.is_winding_up: 
					champion.is_winding_up = false
				
				# FIX: Remove face_mouse_direction() from here.
				# Let _handle_skill_cast manage the facing direction cleanly!
				_handle_skill_cast(champion.auto_attack_slot)
				champion.advance_combo()
				
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
			var stat_range = champion.get_total(Unit.Stat.RANGE)
			current_cast_range = max(stat_range, data.cast_range)
			
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
	
	calculate_facing_direction()

	# 2. Build the dynamic body animation name (e.g., "attack_up", "cast_left")
	var full_anim_name = data.body_animation + "_" + last_facing
	
	# 3. Play the directional animation, or gracefully drop back to a directional idle
	if champion.anim_player and champion.anim_player.has_animation(full_anim_name):
		champion.anim_player.play(full_anim_name)
	elif champion.anim_player:
		# If your character sheet doesn't have "attack_up", they will just 
		# look up in their "idle_up" pose while the VFX sword slash handles the 360 visual!
		champion.anim_player.play("idle_" + last_facing)
		
	# 4. Activate the skill rules (Spawns your 360-degree rotated VFX hitboxes!)
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
# --- ANIMATION HELPERS ---

# --- ANIMATION HELPERS ---

func update_movement_anim(input_dir: Vector2, is_moving: bool):
	# Use 'animator' instead of checking the node tree every frame via string strings
	if not is_instance_valid(champion) or not champion.anim_player: return
	
	if input_dir.x > 0: last_facing = "right"
	elif input_dir.x < 0: last_facing = "left"
	elif input_dir.y < 0: last_facing = "up"
	elif input_dir.y > 0: last_facing = "down"
	
	var anim_state = "walk_" if is_moving else "idle_"
	champion.anim_player.play(anim_state + last_facing)


func calculate_facing_direction() -> String:
	if not is_instance_valid(champion): return last_facing
	
	var mouse_pos = champion.get_global_mouse_position()
	var dir_to_mouse = (mouse_pos - champion.global_position).normalized()
	var angle = dir_to_mouse.angle() 
	
	const QUARTER_PI = PI / 4.0
	if angle >= -QUARTER_PI and angle < QUARTER_PI:
		last_facing = "right"
	elif angle >= QUARTER_PI and angle < 3 * QUARTER_PI:
		last_facing = "down"
	elif angle >= -3 * QUARTER_PI and angle < -QUARTER_PI:
		last_facing = "up"
	else:
		last_facing = "left"
		
	return last_facing
	
func face_mouse_direction():
	if not is_instance_valid(champion): return
	
	var mouse_pos = champion.get_global_mouse_position()
	var dir_to_mouse = (mouse_pos - champion.global_position).normalized()
	var angle = dir_to_mouse.angle() 
	
	# Convert 360 degree angle into 4 quadrants
	const QUARTER_PI = PI / 4.0
	if angle >= -QUARTER_PI and angle < QUARTER_PI:
		last_facing = "right"
	elif angle >= QUARTER_PI and angle < 3 * QUARTER_PI:
		last_facing = "down"
	elif angle >= -3 * QUARTER_PI and angle < -QUARTER_PI:
		last_facing = "up"
	else:
		last_facing = "left"
		
	# Snap the body to an idle pose facing the mouse while the weapon handles the 360 slash
	if champion.has_node("AnimationPlayer"):
		champion.get_node("AnimationPlayer").play("idle_" + last_facing)
