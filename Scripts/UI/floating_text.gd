extends RichTextLabel

static var _clock_index: int = 0

func start(amount: float, start_pos: Vector2, type: String = "physical", is_crit: bool = false):
	if amount < 1:
		queue_free()
		return

	# 1. Basic Setup
	bbcode_enabled = true
	fit_content = true 
	autowrap_mode = TextServer.AUTOWRAP_OFF
	clip_contents = false 

	# 2. Sequential Clockwise Trajectory
	var starting_hour: float = 9.0
	var current_hour = fmod(starting_hour + _clock_index, 12.0)
	_clock_index = (_clock_index + 1) % 12
	
	var hour_angle: float = (current_hour / 12.0) * (2.0 * PI) - (PI / 2.0)
	var direction = Vector2.RIGHT.rotated(hour_angle)

	# 3. Build the Rich Text String FIRST so Godot knows how big it is
	var color_str = "white"
	var icon_tag = ""
	var display_amount = str(floor(amount))
	var icon_size = 8 
	
	match type:
		"physical":
			color_str = StatStyle.get_color("attack_damage")
			icon_tag = StatStyle.get_icon_tag("attack_damage", icon_size)
		"magic":
			color_str = StatStyle.get_color("ability_power")
			icon_tag = StatStyle.get_icon_tag("ability_power", icon_size)
		"heal":
			color_str = StatStyle.get_color("health")
			icon_tag = StatStyle.get_icon_tag("health", icon_size)
		"gold":
			color_str = StatStyle.get_color("gold")
			icon_tag = StatStyle.get_icon_tag("gold", icon_size)
		"exp":
			color_str = "palegreen" 
			icon_tag = "[b]XP[/b]" 
		"true":
			color_str = "white"
			icon_tag = "✨"

	var final_text = "[center][font_size=8]" 
	if type == "heal" or type == "gold":
		final_text += "[color=%s]+%s %s[/color]" % [color_str, display_amount, icon_tag]
	else:
		final_text += "[color=%s]-%s %s[/color]" % [color_str, display_amount, icon_tag]
	
	if is_crit and type != "gold":
		final_text += " [color=yellow]![/color]" 
		
	final_text += "[/font_size][/center]"
	text = final_text

	# --- FIX 1: FORCE INSTANT SIZE GENERATION ---
	reset_size() 
	var text_size = get_minimum_size()

	# --- FIX 2: OFFSET THE START POSITION BY HALF THE TEXT SIZE ---
	# This drags the top-left corner left and up, centering the label's middle perfectly on the target!
	var centered_start_pos = start_pos - (text_size / 2.0)
	global_position = centered_start_pos
	
	# Calculate the float-away destination relative to our new centered home base
	var spread_distance = randf_range(25, 30)
	var target_pos = global_position + (direction * spread_distance)

	# 5. Animation (Tween)
	var scale_target = Vector2(1.3, 1.3) if is_crit else Vector2(1.0, 1.0)
	var tween = create_tween().set_parallel(true)
	
	# Lock the scale pivot directly to the dead center of our freshly centered box
	pivot_offset = text_size / 2.0
	
	# Pop & Scale
	scale = Vector2.ZERO
	tween.tween_property(self, "scale", scale_target, 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
	# Movement
	tween.tween_property(self, "global_position", target_pos, 0.45)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	# Fade Out
	tween.tween_property(self, "modulate:a", 0.0, 0.2).set_delay(0.25)
	
	# Destroy
	tween.chain().tween_callback(queue_free)
