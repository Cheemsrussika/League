extends HBoxContainer

var player_inventory: InventoryComponent
@export var slot_scene: PackedScene 
@export var info_panel: Control
@export var max_slots:int=6

func _ready():
	for i in range(max_slots):
		var slot = slot_scene.instantiate()
		add_child(slot)
		slot.slot_index = i
		slot.stored_item = null
		slot.set_item(null)
		slot.hovered.connect(_on_slot_hovered)
		slot.unhovered.connect(_on_slot_unhovered)
		
		# --- NEW: Connect a click signal to unequip ---
		# (Assuming your slot UI has a button or gui_input you can link here)
		if slot.has_signal("slot_clicked"): # Or whatever your click signal is named
			slot.slot_clicked.connect(_on_slot_clicked)

# --- NEW UNEQUIP LOGIC ---
func _on_slot_clicked(slot_index: int):
	if not is_instance_valid(player_inventory): return
	
	var item = player_inventory.items[slot_index]
	if item == null: return # Nothing to unequip
	
	var player = GameManager.player_champion
	var backpack = player.get_node_or_null("BackpackComponent")
	
	if backpack:
		# Try to put it in the backpack
		var overflow = backpack.add_item(item, 1)
		if overflow == 0:
			# It fit! Remove it from our equipment slots
			player_inventory.remove_item(slot_index)
		else:
			print("Backpack is full! Cannot unequip.")

# ... (The rest of your script: _on_slot_hovered, _process, _setup_connection, refresh_slots remain exactly the same) ...

func _on_slot_hovered(slot_node):
	if info_panel and slot_node.stored_item:
		info_panel.display(slot_node.stored_item)

func _on_slot_unhovered():
	if info_panel:
		info_panel.hide_tooltip()


func _process(_delta):
	if is_instance_valid(player_inventory):
		set_process(false)
		return
	var player = GameManager.player_champion
	if is_instance_valid(player):
		for child in player.get_children():
			if child is InventoryComponent:
				player_inventory = child
				_setup_connection()
				break

func _setup_connection():
	if player_inventory.inventory_changed.connect(refresh_slots) != OK:
		print("Error connecting signal")
	refresh_slots()

func refresh_slots():
	if not player_inventory: return
	
	var slots = get_children()

	for i in range(player_inventory.items.size()):
		if i < slots.size():
			var item_data = player_inventory.items[i]
			var slot_ui = slots[i]
			
			if slot_ui.has_method("set_item"):
				slot_ui.set_item(item_data)
				
			# ADD THIS LINE so the slot knows what it is holding for the hover tooltip!
			slot_ui.stored_item = item_data
