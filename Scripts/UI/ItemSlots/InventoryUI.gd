extends HBoxContainer

var player_inventory: InventoryComponent
@export var slot_scene: PackedScene 
@export var info_panel: Control
@export var max_slots:int=10

func _ready():
	for i in range(max_slots):
		var slot = slot_scene.instantiate()
		add_child(slot)
		if info_panel == null:
				info_panel = get_tree().get_first_node_in_group("item_tooltip")
		# Tell the slot it lives in the Inventory!
		slot.source_panel = "inventory"
		slot.slot_index = i
		slot.stored_item = null
		slot.set_item(null)
		if slot.has_signal("hovered"): slot.hovered.connect(_on_slot_hovered)
		if slot.has_signal("unhovered"): slot.unhovered.connect(_on_slot_unhovered)
		
		# Connect our new universal signals
		slot.slot_double_clicked.connect(_on_slot_double_clicked.bind(i))
		slot.slot_dropped.connect(_on_slot_dropped.bind(i))

# --- UNEQUIP ON DOUBLE CLICK ---
func _on_slot_double_clicked(slot_index: int):
	if not is_instance_valid(player_inventory): return
	
	var item = player_inventory.items[slot_index]
	if item == null: return
	
	var player = GameManager.player_champion
	var backpack = player.get_node_or_null("BackpackComponent")
	
	if backpack:
		var overflow = backpack.add_item(item, 1)
		if overflow == 0:
			player_inventory.remove_item(slot_index)
			
		else:
			DevMenu.add_log("Backpack is full! Cannot unequip.")

# --- SWAP ON DROP ---
func _on_slot_dropped(drag_data: Dictionary, target_index: int):
	# Only allow swapping if the item came from the inventory panel itself
	if drag_data["source"] == "inventory":
		var from_index = drag_data["origin_index"]
		
		# Swap the items in the data array
		var temp = player_inventory.items[target_index]
		player_inventory.items[target_index] = player_inventory.items[from_index]
		player_inventory.items[from_index] = temp
		
		# Tell the system to redraw
		player_inventory.inventory_changed.emit()

func _on_slot_hovered(slot_node):
	if info_panel and slot_node.get("stored_item"):
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
		DevMenu.add_log("Error connecting signal")
	
	# CONNECT THE COOLDOWN SIGNAL HERE:
	if not player_inventory.item_went_on_cooldown.is_connected(_on_item_went_on_cooldown):
		player_inventory.item_went_on_cooldown.connect(_on_item_went_on_cooldown)
		
	refresh_slots()

# AND ADD THIS FUNCTION AT THE BOTTOM OF THAT SCRIPT:
func _on_item_went_on_cooldown(slot_index: int, duration: float):
	var slots = get_children()
	if slot_index >= 0 and slot_index < slots.size():
		var slot_ui = slots[slot_index]
		if slot_ui.has_method("start_cooldown"):
			slot_ui.start_cooldown(duration)
			
			
func refresh_slots():
	if not player_inventory: return
	var slots = get_children()
	for i in range(player_inventory.items.size()):
		if i < slots.size():
			var item_data = player_inventory.items[i]
			var slot_ui = slots[i]
			
			if slot_ui.has_method("set_item"):
				slot_ui.set_item(item_data)
			slot_ui.stored_item = item_data
