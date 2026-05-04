extends HBoxContainer

var player_consumables: ConsumablesComponent
@export var slot_scene: PackedScene 
@export var info_panel: Control
@export var max_slots:int=10

func _ready():
	for i in range(max_slots):
		var slot = slot_scene.instantiate()
		add_child(slot)
		
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
# --- UNEQUIP ON DOUBLE CLICK ---
func _on_slot_double_clicked(slot_index: int):
	if not is_instance_valid(player_consumables): return
	
	var item = player_consumables.items[slot_index]
	if item == null: return
	
	# 1. Grab the exact amount of items in this slot!
	var amount = player_consumables.stacks[slot_index]
	
	var player = GameManager.player_champion
	var backpack = player.get_node_or_null("BackpackComponent")
	
	if backpack:
		# 2. Pass the 'amount' variable instead of the hardcoded '1'
		var overflow = backpack.add_item(item, amount)
		
		if overflow == 0:
			player_consumables.remove_item(slot_index) # -1 is the default, which clears the whole slot
			
		else:
			# If there was overflow, only remove what actually fit into the backpack
			var amount_that_fit = amount - overflow
			player_consumables.remove_item(slot_index, amount_that_fit)
			DevMenu.add_log("Backpack is full! Some items couldn't be unequiped.")

# --- SWAP ON DROP ---
func _on_slot_dropped(drag_data: Dictionary, target_index: int):
	# If dragged from Backpack to Consumable Slot
	if drag_data["source"] == "backpack":
		var item = drag_data["item"]
		# Optional: Check if item is actually a consumable!
		if not item.get("is_consumable"): 
			DevMenu.add_log("You can only equip consumables here!")
			return
			
		var leftover = player_consumables.equip_consumable(item, drag_data["amount"], target_index)
		if leftover == 0:
			# Tell backpack to remove it
			var player = GameManager.player_champion
			player.get_node("BackpackComponent").remove_item(drag_data["origin_index"])
func _on_slot_hovered(slot_node):
	if info_panel and slot_node.get("stored_item"):
		info_panel.display(slot_node.stored_item)

func _on_slot_unhovered():
	if info_panel:
		info_panel.hide_tooltip()

func _process(_delta):
	if is_instance_valid(player_consumables):
		set_process(false)
		return
	var player = GameManager.player_champion
	if is_instance_valid(player):
		for child in player.get_children():
			if child is ConsumablesComponent:
				player_consumables = child
				_setup_connection()
				break

func _setup_connection():
	
	if player_consumables.consumables_changed.connect(refresh_slots) != OK:
		DevMenu.add_log("Error connecting signal")
		
	refresh_slots()
func refresh_slots():
	if not player_consumables: return
	var slots = get_children()
	for i in range(player_consumables.items.size()):
		if i < slots.size():
			var item_data = player_consumables.items[i]
			var slot_ui = slots[i]
			var amount = player_consumables.stacks[i]
			if slot_ui.has_method("set_amount"):
				slot_ui.set_amount(amount)
			if slot_ui.has_method("set_item"):
				slot_ui.set_item(item_data)
			slot_ui.stored_item = item_data
