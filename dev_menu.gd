extends CanvasLayer

var item_catalog: Dictionary = {}
const ITEM_FOLDER_PATH = "res://Item" 

# Match these to the exact string keys used in your Unit's base_stats dictionary!
var stat_keys = [
	"attack_damage", "armor", "magic_res", "health", "movement_speed", "attack_speed", "crit_chance"
]

func _ready():
	visible = false 
	%LogPanel.visible = false
	
	_scan_items_recursive(ITEM_FOLDER_PATH)
	_populate_item_dropdown()
	_populate_stat_dropdown()
	
	%GiveButton.pressed.connect(_on_give_item_button_pressed)
	%ApplyStatButton.pressed.connect(_on_apply_stat_pressed)
	
	# --- NEW: Connect the clear button ---
	if has_node("%ClearLogButton"):
		%ClearLogButton.pressed.connect(_on_clear_log_pressed)

func _process(_delta):
	if is_instance_valid(GameManager.selected_unit):
		%TargetLabel.text = " DEV MENU | Target: " + GameManager.selected_unit.name + " "
	else:
		%TargetLabel.text = " DEV MENU | Target: NONE "
# --- NEW: Clear Log Function ---
func _on_clear_log_pressed():
	if has_node("%LogText"):
		%LogText.clear() # This instantly wipes all text!
		add_log("Log cleared.") # Optional: add a starting message back in
func _input(event):
	# F3 toggles the entire Dev Menu
	if event.is_action_pressed("open_dev") or (event is InputEventKey and event.keycode == KEY_F3 and event.pressed):
		visible = !visible
		
	# F4 toggles ONLY the Log Window (so you can see logs while playing)
	if event is InputEventKey and event.keycode == KEY_F4 and event.pressed:
		if visible: # Only allow toggling log if DevMenu is open
			%LogPanel.visible = !%LogPanel.visible

# --- LOGGING SYSTEM ---
func add_log(message: String):
	var time_string = Time.get_time_string_from_system()
	var formatted_msg = "[color=gray][%s][/color] %s\n" % [time_string, message]
	
	# Send to the UI log
	if has_node("%LogText"):
		%LogText.append_text(formatted_msg)
		
	# Still print to Godot's normal output!
	print(message) 

# --- STAT MODIFICATION ---
func _populate_stat_dropdown():
	%StatDropdown.clear()
	for stat in stat_keys:
		# Makes "attack_damage" look like "Attack Damage" in the dropdown
		%StatDropdown.add_item(stat.capitalize()) 

func _on_apply_stat_pressed():
	var target = GameManager.selected_unit
	if not is_instance_valid(target):
		add_log("Error: No target selected to modify stats!")
		return
		
	var selected_idx = %StatDropdown.get_selected_id()
	var stat_to_modify = stat_keys[selected_idx]
	var new_value = %StatValue.value
	
	# Safely check if the target has a base_stats dictionary
	if target.get("base_stats") != null and target.base_stats.has(stat_to_modify):
		target.base_stats[stat_to_modify] = new_value
		
		# Force the unit to recalculate their totals
		if target.has_method("recalculate_stats"):
			target.recalculate_stats()
			
		add_log("Modified %s's %s to %.1f" % [target.name, stat_to_modify, new_value])
		
		# Refresh the Inspect Panel if it's open
		var inspect_ui = get_tree().get_first_node_in_group("inspect_panel")
		if inspect_ui and inspect_ui.visible:
			inspect_ui.refresh_data()
	else:
		add_log("Error: Target does not have a base_stats key for " + stat_to_modify)

# --- ITEM SCANNER (Unchanged) ---
func _scan_items_recursive(path: String):
	var dir = DirAccess.open(path)
	if not dir: return
	
	# Get the name of the current folder (e.g., "Boots" or "Legend")
	var folder_name = path.get_file()
	
	# Initialize the category in our catalog if it doesn't exist
	if not item_catalog.has(folder_name):
		item_catalog[folder_name] = []

	for file in dir.get_files():
		if file.ends_with(".tres") or file.ends_with(".res"):
			var resource = load(path + "/" + file)
			if resource and "item_name" in resource:
				item_catalog[folder_name].append(resource)
				
	for sub_dir in dir.get_directories():
		_scan_items_recursive(path + "/" + sub_dir)
func _populate_item_dropdown():
	%ItemDropdown.clear()
	
	# Get all folder names and sort them (Boots, Basic, etc.)
	var categories = item_catalog.keys()
	categories.sort()
	
	for category in categories:
		var items_in_cat = item_catalog[category]
		if items_in_cat.is_empty(): continue
		
		# Add a Header (Separator) for the folder name
		%ItemDropdown.add_separator("--- " + category.to_upper() + " ---")
		
		# Sort items within this category alphabetically
		items_in_cat.sort_custom(func(a, b): return a.item_name < b.item_name)
		
		for item in items_in_cat:
			# We store the actual resource as metadata so we can retrieve it easily
			var index = %ItemDropdown.get_item_count()
			%ItemDropdown.add_item("  " + item.item_name)
			%ItemDropdown.set_item_metadata(index, item)
			
	add_log("Catalog organized by folders!")

		
func _on_give_item_button_pressed():
	var target = GameManager.selected_unit
	if not is_instance_valid(target) or not target.get("inventory"):
		add_log("Error: No valid target with inventory!")
		return
		
	var selected_idx = %ItemDropdown.get_selected_id()
	# Retrieve the item resource we stored in the metadata
	var item_to_give = %ItemDropdown.get_item_metadata(selected_idx)
	
	if item_to_give:
		target.inventory.add_item(item_to_give) 
		add_log("Gave %s to %s" % [item_to_give.item_name, target.name])
		
		# Refresh the Inspect Panel if it's open
		var inspect_ui = get_tree().get_first_node_in_group("inspect_panel")
		if inspect_ui and inspect_ui.visible:
			inspect_ui.refresh_data()
