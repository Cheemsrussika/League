extends Champion


var current_target: Champion = null

func _ready():
	super._ready()
	add_to_group("player")

func _physics_process(delta: float) -> void:
	handle_movement()
	handle_combat() 
	_handle_cooldowns(delta)
	handle_regeneration(delta)
	handle_gold_generation(delta)

func handle_movement():
	var direction = Input.get_vector("a", "d", "w", "s")
	var speed = get_total(Stat.MS) 
	velocity = direction * speed
	move_and_slide()

func handle_combat():
	if not is_instance_valid(current_target) or current_target.is_dead:
		current_target = null
		return
	var dist = global_position.distance_to(current_target.global_position)
	var my_range = get_total(Stat.RANGE)
	if dist <= my_range:
		try_auto_attack(current_target)

func _input(event):
	if event.is_action_pressed("ui_accept"): 
		take_damage(100, "true", self)
		take_damage(100, "magic", self)
		take_damage(100, "physical", self)
		current_resource -= 100

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var new_target = _get_enemy_under_mouse()
		if new_target:
			current_target = new_target
			print("Locked on: ", current_target.name)
		else:
			current_target = null 
			print("Target cleared")

func _get_enemy_under_mouse() -> Champion:
	var space = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_bodies = true
	var results = space.intersect_point(query)
	for result in results:
		var collider = result.collider
		if collider is Champion and collider != self:
			return collider
	return null
