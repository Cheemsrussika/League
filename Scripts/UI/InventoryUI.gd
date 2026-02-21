extends HBoxContainer

var player_inventory: InventoryComponent
@export var slot_scene: PackedScene 
@export var info_panel: Control
@export var max_slots:int=6
func _ready():
	for i in range(max_slots):
		var slot = slot_scene.instantiate()
		add_child(slot)
		slot.slot_index = i # Tell the slot which index it owns
		slot.stored_item = null
		slot.set_item(null)
		slot.hovered.connect(_on_slot_hovered)
		slot.unhovered.connect(_on_slot_unhovered)

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
