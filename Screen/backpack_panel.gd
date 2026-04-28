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
	_clear_all_ui_slots()

	var counters = { "mat": 0, "equip": 0, "cons": 0 }

	for i in range(backpack_component.slots.size()):
		var slot_data = backpack_component.slots[i]
		if slot_data == null: continue
		
		var item = slot_data.item
		var target_grid = null
		var current_idx = 0

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
		
		if target_grid and current_idx < target_grid.get_child_count():
			var slot_ui = target_grid.get_child(current_idx)
			if slot_ui.has_method("set_item"):
				slot_ui.source_panel = "backpack"
				slot_ui.slot_index = i 
				slot_ui.set_item(slot_data)
				
				# 1. Clear old connections to avoid double-firing
				for connection in slot_ui.slot_double_clicked.get_connections():
					slot_ui.slot_double_clicked.disconnect(connection.callable)
				for connection in slot_ui.slot_dropped.get_connections():
					slot_ui.slot_dropped.disconnect(connection.callable)
					
				# 2. Connect BOTH signals!
				slot_ui.slot_double_clicked.connect(_on_slot_double_clicked.bind(i))
				slot_ui.slot_dropped.connect(_on_slot_dropped.bind(i)) # <-- NEW LINE

# --- SWAP IN BACKPACK ON DROP ---
func _on_slot_dropped(drag_data: Dictionary, target_index: int):
	if drag_data.has("source") and drag_data["source"] == "backpack":
		var from_index = drag_data["index"]
		
		# Swap the slots in the actual BackpackComponent array
		var temp = backpack_component.slots[target_index]
		backpack_component.slots[target_index] = backpack_component.slots[from_index]
		backpack_component.slots[from_index] = temp
		
		# Emit the signal to force the UI to redraw the grids
		backpack_component.backpack_changed.emit()

func _clear_all_ui_slots():
	for g in [mat_grid, equip_grid, cons_grid]:
		for slot in g.get_children():
			if slot.has_method("set_item"):
				slot.set_item(null)

func _on_slot_double_clicked(backpack_index: int):
	var slot_data = backpack_component.slots[backpack_index]
	if slot_data == null: return
	
	var item = slot_data.item
	var player = GameManager.player_champion
	
	if item.item_type == ItemData.ItemType.EQUIPMENT:
		var inventory = player.get_node_or_null("InventoryComponent")
		if inventory and inventory.add_item(item):
			backpack_component.remove_item(item.item_name, 1)
			
			
	elif item.item_type == ItemData.ItemType.CONSUMABLE:
		backpack_component.remove_item(item.item_name, 1)
		
	elif item.item_type == ItemData.ItemType.QUEST_ITEM:
		DevMenu.add_log("Cannot use quest item directly from backpack!")
