extends PanelContainer

signal hovered(slot_instance)
signal unhovered()
@onready var icon_rect = $IconTexture 

var stored_item: ItemData = null
var slot_index: int = -1 

func _ready():
	custom_minimum_size = Vector2(50, 50)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
func _on_mouse_entered():
	if stored_item:
		hovered.emit(self)
func _on_mouse_exited():
	unhovered.emit()
func set_item(item: ItemData):
	stored_item = item
	if not icon_rect: return
	
	if item and item.icon:
		icon_rect.texture = item.icon
		tooltip_text = item.item_name
		icon_rect.modulate = Color.WHITE
	else:
		icon_rect.texture = null
		tooltip_text = "Empty"
		icon_rect.modulate = Color(1, 1, 1, 0.2)

func _get_drag_data(_at_position):
	if stored_item == null: return null
	
	# Create a visual preview following the mouse
	var preview = TextureRect.new()
	preview.texture = icon_rect.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = Vector2(40, 40)
	set_drag_preview(preview)

	return { 
		"origin_index": slot_index, 
		"item": stored_item 
	}

func _can_drop_data(_at_position, data):
	return data is Dictionary and data.has("origin_index")

func _drop_data(_at_position, data):
	var origin_index = data["origin_index"]
	var target_index = slot_index
	
	if origin_index == target_index: return
	var inventory_ui = get_parent() 
	if inventory_ui and inventory_ui.player_inventory:
		inventory_ui.player_inventory.swap_items(origin_index, target_index)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			sell_item()
func sell_item():
	if stored_item == null: return
	
	var player = GameManager.player_champion
	if not is_instance_valid(player): return
	var in_shop_zone = false
	var interaction_area = player.get_node_or_null("InteractionArea")
	
	if interaction_area:
		for area in interaction_area.get_overlapping_areas():
			if area.is_in_group("shop_zone"):
				in_shop_zone = true
				break
	
	if not in_shop_zone:
		print("You must stand in the shop zone to sell!")
		return

	# 2. Check if UI is open
	var shop_ui = get_tree().get_first_node_in_group("shop_ui")
	if shop_ui == null or not shop_ui.visible:
		return

	# 3. Proceed with Selling
	var inventory_comp = player.get_node_or_null("InventoryComponent")
	if not inventory_comp: return

	var refund = int(stored_item.cost * 0.7)
	player.gold += refund
	inventory_comp.remove_item(slot_index)
	
	if player.has_signal("gold_updated"):
		player.gold_updated.emit(player.gold)
		
	get_tree().call_group("shop_buttons", "update_affordability")
