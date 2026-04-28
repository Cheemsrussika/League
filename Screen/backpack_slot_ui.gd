extends Control 

signal slot_double_clicked
signal slot_dropped(drag_data) # Emitted when something is dropped ON this slot

@onready var icon_texture = $IconTexture
@onready var amount_label = $AmountLabel
@onready var click_button = $Button 

var current_slot_data = null
var slot_index: int = -1
var source_panel: String = "" # Will be set to "inventory" or "backpack"

func _ready():
	# Detect double clicks
	click_button.gui_input.connect(_on_button_gui_input)

func set_item(slot_data):
	current_slot_data = slot_data
	if slot_data == null:
		icon_texture.texture = null
		amount_label.text = ""
	else:
		# Handles both Inventory (raw ItemData) and Backpack (SlotData with .item)
		var item = slot_data if slot_data is ItemData else slot_data.item
		icon_texture.texture = item.icon
		
		# Check if amount exists and is > 1
		if typeof(slot_data) == TYPE_DICTIONARY or "amount" in slot_data:
			if slot_data.amount > 1:
				amount_label.text = str(slot_data.amount)
			else:
				amount_label.text = ""
		else:
			amount_label.text = ""

func _on_button_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			if current_slot_data!=null:
				slot_double_clicked.emit()
				get_tree().call_group("shop_buttons", "update_affordability")
			else:
				DevMenu.add_log("The slot is empty")
			

# --- DRAG AND DROP MAGIC ---

func _get_drag_data(at_position: Vector2) -> Variant:
	if current_slot_data == null: return null
	
	var item = current_slot_data if current_slot_data is ItemData else current_slot_data.item
	
	# Create the floating icon
	var preview_icon = TextureRect.new()
	preview_icon.texture = item.icon
	preview_icon.custom_minimum_size = Vector2(40, 40)
	preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	
	var preview = Control.new()
	preview.add_child(preview_icon)
	preview_icon.position = -preview_icon.custom_minimum_size / 2 
	set_drag_preview(preview)

	# Package the info so the drop target knows what is arriving
	return {"source": source_panel, "index": slot_index, "data": current_slot_data}

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("source")

func _drop_data(at_position: Vector2, data: Variant):
	slot_dropped.emit(data)
