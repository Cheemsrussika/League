extends Label

func start(amount: float, start_pos: Vector2, type: String = "physical", is_crit: bool = false):
	if amount<1:
		
		return

	
	
	# 1. Randomize Start Position
	# This prevents them from spawning on the exact same pixel if triggered simultaneously
	var offset_x = randf_range(-25, 25)
	var offset_y = randf_range(-15, 15)
	global_position = start_pos + Vector2(offset_x, offset_y)
	
	# 2. Randomize Movement Direction (Spread Out)
	# Instead of just going UP, we go UP-LEFT or UP-RIGHT randomly
	var spread_distance = randf_range(80, 120)
	var angle = randf_range(-PI / 3, PI / 3) # Spread within a 60-degree cone upwards
	# Convert angle to vector (pointing up is -Y in Godot)
	var direction = Vector2.UP.rotated(angle) 
	var target_pos = global_position + (direction * spread_distance)

	# 3. Color Logic (Same as before)
	modulate = Color.WHITE 
	match type:
		"physical": modulate = Color(1, 0.3, 0.3)
		"magic":    modulate = Color(0.2, 0.2, 1)
		"true":     modulate = Color(1, 1, 1)
		"heal":     modulate = Color(0.3, 1.0, 0.3)
		"exp":     modulate = Color(0.2,0.7, 0.2)
		"gold":     modulate = Color(1, 0.8, 0.2) # Gold
		_:          modulate = Color(1, 1, 1)

	# 4. Size/Crit Logic
	var scale_target = Vector2(1.0, 1.0)
	if type=="exp":
		text=str("+%.0fXP"%[amount])
	if type=="heal":
		text=str("+%.2f➕"%[amount])
	elif type=="gold":
		text= str("+%.0f🪙"%[amount])
	else:
		text = str("-%.1f🗡"%[amount]) 
	
	if is_crit &&type!="gold":
		if  type == "magic":
			modulate=Color(0.2, 0.2, 1)
		else:
			modulate = Color(1, 0.8, 0.2)
		scale_target = Vector2(1.7, 1.7)
		text += "💥"
		z_index = 10
	else:
		# Vary size slightly for normal hits too (0.8 to 1.2) helps visual noise
		var random_size = randf_range(0.9, 1.1)
		scale_target = Vector2(random_size, random_size)
		z_index = 5

	# 5. Animation (Tween)
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Move in the calculated random direction
	tween.tween_property(self, "global_position", target_pos, 0.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Pop Effect
	scale = Vector2.ZERO
	tween.tween_property(self, "scale", scale_target, 0.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_delay(0.2)
	
	# Fade Out
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_delay(0.5)
	
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
