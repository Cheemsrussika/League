extends PanelContainer

signal hovered(slot_instance)
signal unhovered()
signal slot_clicked(index)

# --- NEW SIGNALS FOR DRAG/DROP & DOUBLE CLICK ---
signal slot_double_clicked() 
signal slot_dropped(drag_data) 

@onready var icon_rect = $IconTexture 
@onready var cooldown_overlay = $CooldownOverlay # Adjust path if needed
@onready var cooldown_label = $CooldownLabel     # Adjust path if needed
@onready var amount_label = $AmountLabel
var total_cooldown: float = 0.0
var current_cooldown: float = 0.0

var stored_item: ItemData = null
var slot_index: int = -1 

# --- FIXED ERROR: Added the missing variable! ---
var source_panel: String = "" 

func _ready():
	custom_minimum_size = Vector2(50, 50)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	set_process(false)
	if cooldown_overlay: cooldown_overlay.hide()
	if cooldown_label: cooldown_label.hide()

func start_cooldown(duration_in_seconds: float):
	if not cooldown_overlay or not cooldown_label: return
	
	total_cooldown = duration_in_seconds
	current_cooldown = duration_in_seconds
	
	cooldown_overlay.show()
	cooldown_label.show()
	set_process(true)

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

# --- UPDATED DRAG DATA ---
func _get_drag_data(_at_position):
	if stored_item == null: return null
	
	# Create a visual preview following the mouse
	var preview = TextureRect.new()
	preview.texture = icon_rect.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = Vector2(40, 40)
	
	# Center the preview on the mouse cursor
	var preview_control = Control.new()
	preview_control.add_child(preview)
	preview.position = -preview.size / 2 
	set_drag_preview(preview_control)

	return { 
		"origin_index": slot_index, 
		"item": stored_item,
		"source": source_panel # Tells the receiver where it came from!
	}

func _can_drop_data(_at_position, data):
	return data is Dictionary and data.has("origin_index")

# --- UPDATED DROP LOGIC ---
func _drop_data(_at_position, data):
	# Instead of hardcoding the swap here, we emit the signal so the 
	# Inventory or Backpack scripts can handle cross-panel swapping!
	slot_dropped.emit(data)

# --- UPDATED INPUT FOR DOUBLE CLICKS ---
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		
		# LEFT CLICK BEHAVIOR
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click:
				slot_double_clicked.emit() # Fires unequip/equip!
			else:
				slot_clicked.emit(slot_index) # Normal click
				
		# RIGHT CLICK BEHAVIOR (Activate / Consume)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var player = GameManager.player_champion
			if not is_instance_valid(player): return
			if source_panel == "inventory":
				var inv = player.get_node_or_null("InventoryComponent")
				if inv: inv.use_active_slot(slot_index)
			elif source_panel == "consumables":
				var cons = player.get_node_or_null("ConsumablesComponent")
				if cons: cons.use_consumable(slot_index)
				
				
func _process(delta: float):
	if current_cooldown > 0:
		current_cooldown -= delta
		
		# Update Timer Text (ceil rounds up, so 2.1 shows as "3")
		cooldown_label.text = str(ceil(current_cooldown))
		
		# Optional: Make the dark overlay shrink like a clock wipe!
		# cooldown_overlay.scale.y = current_cooldown / total_cooldown 
	else:
		# Cooldown finished
		set_process(false)
		cooldown_overlay.hide()
		cooldown_label.hide()
		current_cooldown = 0.0
# --- YOUR EXISTING SHOP LOGIC STAYS THE SAME ---
func set_amount(amount: int):
	if amount > 1:
		amount_label.text = str(amount)
		amount_label.show()
	else:
		amount_label.hide() # We usually don't show a number if there's only 1 (or 0)
