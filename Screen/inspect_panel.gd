extends Panel

var current_target: Node = null
var refresh_timer: float = 0.0

func _ready():
	visible = false
	%Close.pressed.connect(_close_panel)

func _input(event):
	if visible and event.is_action_pressed("ui_cancel"): 
		visible = false


func _close_panel():
	visible = false

func open_panel(target_unit: Node):
	current_target = target_unit
	visible = true
	refresh_data() # Instantly draw it the first time

# --- NEW: AUTO REFRESH LOOP ---
func _process(delta):
	if not visible or not is_instance_valid(current_target): 
		return
		
	refresh_timer -= delta
	if refresh_timer <= 0.0:
		refresh_timer = 0.25 # Refreshes 4 times a second
		refresh_data()

# We moved the drawing logic into its own function!# Inside InspectPanel.gd
func refresh_data():
	%NameLabel.text = "[center][b]" + current_target.name + "[/b][/center]"
	var max_hp = current_target.get_total(Unit.Stat.HP)
	%HPLabel.text = "HP: %d / %d" % [current_target.current_health, max_hp]
	
	if current_target.unit_type == Unit.UnitType.CHAMPION:
		%Mana.text = "Resource: %d / %d" % [current_target.current_resource, current_target._get_max_resource()]
		%Mana.show()
	else:
		%Mana.hide()
	
	# --- STATS ---
	var stats_to_show = [
		Unit.Stat.AD,Unit.Stat.AP,
		Unit.Stat.AR, Unit.Stat.MR, Unit.Stat.MS, 
		Unit.Stat.AS, Unit.Stat.RANGE, Unit.Stat.CRIT
	]
	var stats_text = ""
	for stat_enum in stats_to_show:
		var stat_string_key = current_target.STAT_MAP[stat_enum]
		var val = current_target.get_total(stat_enum)
		if stat_enum == Unit.Stat.CRIT: val *= 100.0
		var icon = StatStyle.get_icon_tag(stat_string_key)
		var color = StatStyle.get_color(stat_string_key)
		var display_name = stat_string_key.capitalize().replace("_", " ")
		stats_text += "%s[color=%s]%s: %.1f[/color]\n" % [icon, color, display_name, val]
	%StatsLabel.text = stats_text

	# --- THE FIX: ITEMS ---
	for child in %ItemContainer.get_children(): child.queue_free()
	if is_instance_valid(current_target) and current_target.get("inventory"):
		# Iterate through the Array[ItemData] directly!
		# --- INSIDE refresh_data() in the Items loop ---
		for item in current_target.inventory.items: 
			if item != null: 
				var tex_rect = TextureRect.new()
				tex_rect.texture = item.icon
				
				# --- ADD THIS LINE ---
				tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE 
				# ---------------------
				
				tex_rect.custom_minimum_size = Vector2(50, 50)
				tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE 
				tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tex_rect.tooltip_text = item.item_name 
				%ItemContainer.add_child(tex_rect)

	# --- BUFFS ---
	for child in %BuffContainer.get_children(): child.queue_free()
	if is_instance_valid(current_target) and current_target.get("status_container"):
		for buff in current_target.status_container.get_children():
			var tex_rect = TextureRect.new()
			var buff_id = buff.id if "id" in buff else "unknown"
			tex_rect.texture = StatusLibrary.get_effect_icon(buff_id)
			tex_rect.custom_minimum_size = Vector2(32, 32)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE 
			if "id" in buff: tex_rect.tooltip_text = str(buff.id).capitalize()
			%BuffContainer.add_child(tex_rect)

	# --- BUFFS (USING STATUSLIBRARY) ---
	for child in %BuffContainer.get_children(): child.queue_free()
	if is_instance_valid(current_target.status_container):
		for buff in current_target.status_container.get_children():
			var tex_rect = TextureRect.new()
			
			# Use your new global function to fetch the exact image!
			var buff_id = buff.id if "id" in buff else "unknown"
			tex_rect.texture = StatusLibrary.get_effect_icon(buff_id)
			
			tex_rect.custom_minimum_size = Vector2(32, 32)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			if "id" in buff: tex_rect.tooltip_text = str(buff.id).capitalize()
			%BuffContainer.add_child(tex_rect)
var dragging = false
var drag_offset = Vector2.ZERO

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start dragging and remember where the mouse was relative to the panel corner
				dragging = true
				drag_offset = get_global_mouse_position() - global_position
				# Move to front so it's not behind other UI when dragging
				move_to_front() 
			else:
				# Stop dragging when mouse released
				dragging = false

	if event is InputEventMouseMotion and dragging:
		# Update position based on mouse movement
		global_position = get_global_mouse_position() - drag_offset
