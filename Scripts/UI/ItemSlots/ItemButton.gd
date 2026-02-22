# ItemButton.gd
extends Button

var item_data: ItemData
var is_mouse_inside: bool = false
var tooltip_node: Label = null
@onready var price_label: Label = $PriceLabel

func setup(item: ItemData):
	item_data = item
	icon = item.icon
	tooltip_text = "" 
	if price_label:
		price_label.text = str(item.cost)
	update_affordability()

func _ready():
	add_to_group("shop_buttons")
	pressed.connect(_on_pressed_show_recipe)
	
	tooltip_node = get_tree().get_first_node_in_group("shop_tooltip")
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	update_affordability()

# Renamed to make it clear this DOES NOT buy items
func _on_pressed_show_recipe():
	if not item_data: return
	var recipe_ui = get_tree().get_first_node_in_group("recipe_ui") 
	if recipe_ui:
		recipe_ui.view_recipe(item_data)

func update_affordability():
	if not is_inside_tree() or not item_data or not price_label: return
	
	var player = GameManager.player_champion
	var current_gold = 0.0
	if is_instance_valid(player):
		current_gold = player.gold
		
	if current_gold < item_data.cost:
		price_label.modulate = Color.RED
	else:
		price_label.modulate = Color.GOLDENROD

# --- TOOLTIP LOGIC ---
func _on_mouse_entered():
	is_mouse_inside = true
	if is_instance_valid(tooltip_node):
		tooltip_node.show()    
		update_tooltip_text() 

func _on_mouse_exited():
	is_mouse_inside = false
	if is_instance_valid(tooltip_node):
		tooltip_node.hide()

func _process(_delta):
	if is_mouse_inside and is_instance_valid(tooltip_node) and item_data:
		tooltip_node.global_position = get_global_mouse_position() + Vector2(20, 20)

func update_tooltip_text():
	if not is_instance_valid(tooltip_node): return
	var text = item_data.item_name + " (" + str(item_data.cost) + " Gold)\n"
	if Input.is_key_pressed(KEY_SHIFT):
		text += "--------------------\n"
		text += "Stats: " + _get_stat_summary() + "\n"
		text += str(item_data.get("description")) if item_data.get("description") else ""
	else:
		text += "[Hold Shift for Details]"
	tooltip_node.text = text

func _get_stat_summary() -> String:
	if not item_data or not item_data.stats: return ""
	var s = ""
	for key in item_data.stats:
		var val = item_data.stats[key]
		s += "+%s %s " % [str(val), key.replace("_", " ").capitalize()]
	return s
