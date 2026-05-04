extends Control
class_name SaveLoadMenu

# ==========================================
# --- NODE REFERENCES ---
# ==========================================
@onready var save_button: Button = $SaveButton
@onready var load_button: Button = $LoadButton
@onready var status_label: Label = $StatusLabel

# ==========================================
# --- INITIALIZATION ---
# ==========================================
func _ready() -> void:
	# Safely connect the buttons to our functions
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if load_button:
		load_button.pressed.connect(_on_load_pressed)
		
	# Clear the label on startup
	if status_label:
		status_label.text = ""

# ==========================================
# --- BUTTON ACTIONS ---
# ==========================================
func _on_save_pressed() -> void:
	# Change "slot_1" to whatever file name you prefer
	SaveManager.save_game("slot_1")
	
	if status_label:
		status_label.text = "Game Saved Successfully!"
		status_label.modulate = Color.GREEN
		
	DevMenu.add_log("Player triggered a save.")

func _on_load_pressed() -> void:
	var success = SaveManager.load_game("slot_1")
	
	if success:
		if status_label:
			status_label.text = "Game Loaded Successfully!"
			status_label.modulate = Color.GREEN
			
		DevMenu.add_log("Player loaded a save.")
		
		# Optional: Hide the menu automatically after loading
		# visible = false 
		
	else:
		if status_label:
			status_label.text = "No save file found!"
			status_label.modulate = Color.RED
			
		DevMenu.add_log("Failed to load game.")

# ==========================================
# --- TOGGLE MENU (OPTIONAL) ---
# ==========================================
# You can call this from your main game script when pressing "Escape"
func toggle_menu() -> void:
	visible = !visible
	if visible and status_label:
		status_label.text = "" # Reset text when opening
