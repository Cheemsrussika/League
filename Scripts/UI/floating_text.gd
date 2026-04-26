extends RichTextLabel

func start(amount: float, start_pos: Vector2, type: String = "physical", is_crit: bool = false):
	if amount < 1:
		queue_free()
		return

	# 1. Basic Setup
	bbcode_enabled = true
	fit_content = true # Important so the box doesn't cut off text
	autowrap_mode = TextServer.AUTOWRAP_OFF
	
	# 2. Randomize Position & Direction
	var offset = Vector2(randf_range(-25, 25), randf_range(-15, 15))
	global_position = start_pos + offset
	
	var spread_distance = randf_range(80, 120)
	var direction = Vector2.UP.rotated(randf_range(-PI/3, PI/3))
	var target_pos = global_position + (direction * spread_distance)

	# 3. Get Style Data from our Helper
	var color_str = "white"
	var icon_tag = ""
	var display_amount = str(floor(amount))
	
	match type:
		"physical":
			color_str = StatStyle.get_color("attack_damage")
			icon_tag = StatStyle.get_icon_tag("attack_damage", 22)
		"magic":
			color_str = StatStyle.get_color("ability_power")
			icon_tag = StatStyle.get_icon_tag("ability_power", 22)
		"heal":
			color_str = StatStyle.get_color("health")
			icon_tag = StatStyle.get_icon_tag("health", 22)
		"gold":
			color_str = StatStyle.get_color("gold")
			icon_tag = StatStyle.get_icon_tag("gold", 22)
		"exp":
			color_str = "palegreen" # Custom color for EXP
			icon_tag = "[b]XP[/b]" # Or use an icon if you have one
		"true":
			color_str = "white"
			icon_tag = "✨"

	# 4. Build the Rich Text String
	var final_text = "[center]" # Center align inside the label
	
	if type == "heal" or type == "gold":
		final_text += "[color=%s]+%s %s[/color]" % [color_str, display_amount, icon_tag]
	else:
		final_text += "[color=%s]-%s %s[/color]" % [color_str, display_amount, icon_tag]
	
	if is_crit and type != "gold":
		final_text += " [b]💥[/b]"
		
	final_text += "[/center]"
	text = final_text

	# 5. Animation (Tween)
	var scale_target = Vector2(1.5, 1.5) if is_crit else Vector2(1.0, 1.0)
	var tween = create_tween().set_parallel(true)
	
	# Movement
	tween.tween_property(self, "global_position", target_pos, 0.4)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Pop & Scale
	scale = Vector2.ZERO
	pivot_offset = size / 2 # Center the scale point
	tween.tween_property(self, "scale", scale_target, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
	# Fade and Destroy
	tween.set_parallel(false)
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_delay(0.4)
	tween.tween_callback(queue_free)
