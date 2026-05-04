extends Panel

## Add this panel to your HUD. Add it to the group "pickup_list_panel".
## Scene needs:
##   - VBoxContainer or ScrollContainer > VBoxContainer ($ItemList)
##   - A close button ($CloseButton)
##   - A label for the title ($TitleLabel) — optional

@onready var item_list: VBoxContainer = $ScrollContainer/ItemList
@onready var close_button: Button = $CloseButton
@onready var title_label: Label = $TitleLabel  # Optional

# Row scene — see PickupListRow.gd
const ROW_SCENE = preload("res://Scripts/UI/pickup_list_row.tscn")

var _current_unit: Unit = null
var _current_items: Array[WorldItem] = []

func _ready() -> void:
	add_to_group("pickup_list_panel")
	visible = false
	close_button.pressed.connect(close_panel)

# -----------------------------------------------------------
# Called by InteractionArea
# -----------------------------------------------------------
func open_for_items(items: Array[WorldItem], unit: Unit) -> void:
	_current_unit = unit
	_current_items = items
	_rebuild_list()
	visible = true

func close_panel() -> void:
	visible = false
	_current_items = []
	_current_unit = null

# -----------------------------------------------------------
# Rebuild the scroll list rows
# -----------------------------------------------------------
func _rebuild_list() -> void:
	# Clear old rows
	for child in item_list.get_children():
		child.queue_free()

	if title_label:
		title_label.text = "Nearby Items (%d)" % _current_items.size()

	for world_item in _current_items:
		if not is_instance_valid(world_item): continue
		if world_item.item_data == null: continue

		var row = ROW_SCENE.instantiate()
		item_list.add_child(row)
		row.setup(world_item.item_data, world_item.item_amount)

		# When the row button is clicked, pick up that specific world item
		row.pickup_requested.connect(_on_row_pickup_requested.bind(world_item))

# -----------------------------------------------------------
# Row callback
# -----------------------------------------------------------
func _on_row_pickup_requested(world_item: WorldItem) -> void:
	if not is_instance_valid(world_item) or _current_unit == null:
		_rebuild_list()
		return

	world_item.try_pickup(_current_unit)

	# Remove from our local list and refresh
	_current_items.erase(world_item)

	if _current_items.is_empty():
		close_panel()
	else:
		_rebuild_list()
