extends Node

const SAVE_DIR = "user://saves/"

# This is the master dictionary that holds the entire game's memory
var current_save: Dictionary = {
	"version": "1.0",
	"player": {
		"champion_id": "Garen",
		"level": 1,
		"current_hp": 100,
		"money": 0
	},
	"inventory": {
		"equipped": [],
		"backpack": []
	},
	"flags": {} # Bosses, doors, and story events go here!
}

func _ready():
	DirAccess.make_dir_absolute(SAVE_DIR)

# --- SAVE LOGIC (With Corruption Prevention) ---
func save_game(slot_name: String = "autosave"):
	_gather_game_state()
	
	var save_path = SAVE_DIR + slot_name + ".json"
	var temp_path = save_path + ".tmp"
	
	var json_string = JSON.stringify(current_save, "\t")
	
	# BEST PRACTICE: Atomic Saving. 
	# Write to a .tmp file first. If the PC crashes during this, the real save is safe.
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		
		# Now that it's safely written, overwrite the actual save file
		DirAccess.rename_absolute(temp_path, save_path)
		print("Game saved successfully to: ", save_path)
	else:
		push_error("Failed to save game.")

# --- LOAD LOGIC ---
func load_game(slot_name: String = "autosave") -> bool:
	var save_path = SAVE_DIR + slot_name + ".json"
	
	if not FileAccess.file_exists(save_path):
		print("No save file found at: ", save_path)
		return false
		
	var file = FileAccess.open(save_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var parsed_data = JSON.parse_string(json_string)
	if typeof(parsed_data) == TYPE_DICTIONARY:
		current_save = parsed_data
		_distribute_game_state()
		print("Game loaded successfully from: ", save_path)
		return true
	else:
		push_error("Save file corrupted!")
		return false

# --- GATHER & DISTRIBUTE DATA ---

# Pulls data FROM the game world INTO the dictionary
func _gather_game_state():
	var player = GameManager.player_champion
	if is_instance_valid(player):
		
		# 1. Save Player State
		current_save["player"]["level"] = player.level
		current_save["player"]["experience"] = player.experience
		current_save["player"]["current_hp"] = player.current_health
		current_save["player"]["current_resource"] = player.current_resource
		current_save["player"]["money"] = player.gold
		
		# 2. Save Inventories
		if player.has_node("InventoryComponent"):
			current_save["inventory"]["equipped"] = player.get_node("InventoryComponent").get_save_data()
			
		if player.has_node("BackpackComponent"):
			current_save["inventory"]["backpack"] = player.get_node("BackpackComponent").get_save_data()
			
		if player.has_node("ConsumablesComponent"):
			current_save["inventory"]["consumables"] = player.get_node("ConsumablesComponent").get_save_data()

func _distribute_game_state():
	var player = GameManager.player_champion
	if is_instance_valid(player):
		
		# 1. Load Player Level (Using Option 2!)
		player.load_saved_level(current_save["player"]["level"], current_save["player"].get("experience", 0.0))
		
		# 2. Load Inventories (Must happen BEFORE current HP so item bonuses apply properly)
		if player.has_node("InventoryComponent") and current_save["inventory"].has("equipped"):
			player.get_node("InventoryComponent").load_save_data(current_save["inventory"]["equipped"])
			
		if player.has_node("BackpackComponent") and current_save["inventory"].has("backpack"):
			player.get_node("BackpackComponent").load_save_data(current_save["inventory"]["backpack"])
			
		if player.has_node("ConsumablesComponent") and current_save["inventory"].has("consumables"):
			player.get_node("ConsumablesComponent").load_save_data(current_save["inventory"]["consumables"])
			
		# 3. Apply Current HP/Money
		player.current_health = current_save["player"]["current_hp"]
		player.current_resource = current_save["player"].get("current_resource", player.current_resource)
		player.gold = current_save["player"]["money"]
		
		# Trigger an update so the UI knows
		player.recalculate_stats()
# --- WORLD FLAGS (Bosses / Story) ---
func set_flag(flag_id: String, value: bool):
	current_save["flags"][flag_id] = value

func get_flag(flag_id: String, default_value: bool = false) -> bool:
	return current_save["flags"].get(flag_id, default_value)
