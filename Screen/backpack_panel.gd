extends Panel

var backpack_component: BackpackComponent
@export var slot_scene: PackedScene 

# Get references to the specific grids in each tab
@onready var mat_grid = %MatGrid 
@onready var equip_grid = %EquipGrid
@onready var cons_grid = %ConsGrid

func _ready():
	visible = false 

func _input(event):
	if event.is_action_pressed("open_backpack"):
		visible = !visible

func _process(_delta):
	if is_instance_valid(backpack_component):
		set_process(false)
		return
		
	var player = GameManager.player_champion
	if is_instance_valid(player):
		backpack_component = player.get_node_or_null("BackpackComponent")
		if backpack_component:
			_setup_connection()

func _setup_connection():
	# 1. Clear old slots
	for g in [mat_grid, equip_grid, cons_grid]:
		for child in g.get_children(): child.queue_free()
		
	# 2. Create the UI slot pool
	# We create enough slots for the backpack capacity in each tab
	_fill_grid(mat_grid, 63) # High capacity for Materials
	_fill_grid(equip_grid, 49) 
	_fill_grid(cons_grid, 42)
			
	backpack_component.backpack_changed.connect(refresh_slots)
	refresh_slots()

func _fill_grid(grid: GridContainer, count: int):
	for i in range(count):
		var slot = slot_scene.instantiate()
		grid.add_child(slot)

func refresh_slots():
	if not backpack_component: return
	
	# Reset all UI slots first
	_clear_all_ui_slots()

	# Tracking how many slots we've filled in each tab UI
	var counters = { "mat": 0, "equip": 0, "cons": 0 }

	# Sort items from the single backpack array into the 3 UI grids
	for i in range(backpack_component.slots.size()):
		var slot_data = backpack_component.slots[i]
		if slot_data == null: continue
		
		var item = slot_data.item
		var target_grid = null
		var current_idx = 0

		# SORTING LOGIC
		match item.item_type:
			ItemData.ItemType.MATERIAL, ItemData.ItemType.QUEST_ITEM:
				target_grid = mat_grid
				current_idx = counters.mat
				counters.mat += 1
			ItemData.ItemType.EQUIPMENT:
				target_grid = equip_grid
				current_idx = counters.equip
				counters.equip += 1
			ItemData.ItemType.CONSUMABLE:
				target_grid = cons_grid
				current_idx = counters.cons
				counters.cons += 1
		
		# Assign to UI
		if target_grid and current_idx < target_grid.get_child_count():
			var slot_ui = target_grid.get_child(current_idx)
			if slot_ui.has_method("set_item"):
				slot_ui.set_item(slot_data)
				
				# Disconnect old signals then connect new one with the REAL index 'i'
				for connection in slot_ui.pressed.get_connections():
					slot_ui.pressed.disconnect(connection.callable)
				slot_ui.pressed.connect(_on_slot_clicked.bind(i))

func _clear_all_ui_slots():
	for g in [mat_grid, equip_grid, cons_grid]:
		for slot in g.get_children():
			if slot.has_method("set_item"):
				slot.set_item(null)

func _on_slot_clicked(backpack_index: int):
	var slot_data = backpack_component.slots[backpack_index]
	if slot_data == null: return
	
	var item = slot_data.item
	var player = GameManager.player_champion
	
	# 1. Equipment Logic
	if item.item_type == ItemData.ItemType.EQUIPMENT:
		var inventory = player.get_node_or_null("InventoryComponent")
		if inventory and inventory.add_item(item):
			backpack_component.remove_item(item.item_name, 1)
			
	# 2. Consumable Logic
	elif item.item_type == ItemData.ItemType.CONSUMABLE:
		# Trigger item use effect here
		backpack_component.remove_item(item.item_name, 1)
		
	# 3. Quest Logic
	elif item.item_type == ItemData.ItemType.QUEST_ITEM:
		print("Cannot use quest item directly from backpack!")
