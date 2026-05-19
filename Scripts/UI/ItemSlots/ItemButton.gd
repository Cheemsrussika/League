# ItemButton.gd
extends Button

var item_data: ItemData
var is_mouse_inside: bool = false
var tooltip_node: RichTextLabel = null
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
	
	# REMOVED: pressed.connect(_on_pressed_show_recipe)
	# We will handle clicks in _gui_input now
	
	tooltip_node = get_tree().get_first_node_in_group("shop_tooltip")
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	update_affordability()

# Renamed to make it clear this DOES NOT buy items
func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.double_click:
				# Double Click = BUY
				_attempt_purchase()
			else:
				
				_show_recipe()

func _show_recipe():
	if not item_data: return
	var recipe_ui = get_tree().get_first_node_in_group("recipe_ui") 
	if recipe_ui:
		recipe_ui.view_recipe(item_data)

func _attempt_purchase():
	if not item_data: return
	# This calls a global method or tells the ShopPanel to buy it
	# We will hook this up to your GameManager/Inventory logic
	var shop = get_tree().get_first_node_in_group("shop_panel")
	if shop and shop.has_method("_on_item_double_clicked"):
		shop._on_item_double_clicked(item_data)

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

func _on_mouse_entered():
	is_mouse_inside = true
	if not is_instance_valid(tooltip_node):
		tooltip_node = _get_tooltip_node()  # finds the RIGHT panel's tooltip
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
	if not is_instance_valid(tooltip_node) or not item_data: 
		return
	if tooltip_node is RichTextLabel:
		tooltip_node.bbcode_enabled = true
	# Inside your update_tooltip_text() function:

	var gold_icon = StatStyle.get_icon_tag("gold", 18)
	var gold_color = StatStyle.get_color("gold")

	var text = "[center][b][color=gold]%s[/color][/b][/center]\n" % item_data.item_name
	text += "[center]Cost: %s [color=%s]%d Gold[/color][/center]\n" % [gold_icon, gold_color, item_data.cost]

	text += "[color=gray]--------------------[/color]\n"
	
	# Stats - Removed the aquamarine wrapper so the individual stat colors work!
	if item_data.stats and item_data.stats.size() > 0:
		text += _get_stat_summary()
		
	# Description
	if item_data.get("description"):
		text += "[color=lightgray][i]" + str(item_data.description) + "[/i][/color]\n"
		


		
	tooltip_node.text = text
# In ItemButton.gd _ready() or lazy lookup:
func _get_tooltip_node() -> RichTextLabel:
	# Walk up the tree to find the tooltip in the SAME panel as this button
	var parent = get_parent()
	while parent:
		var label = parent.find_child("TooltipLabel", true, false)
		if label:
			return label
		parent = parent.get_parent()
	return null
func _get_stat_summary() -> String:
	if not item_data or not item_data.stats: return ""
	var s = ""
	for key in item_data.stats:
		var val = item_data.stats[key]
		var formatted_name = key.replace("_", " ").capitalize()
		
		# Ask our helper for the icon and color!
		var stat_color = StatStyle.get_color(key)
		var stat_icon = StatStyle.get_icon_tag(key, 16) # 16x16 size for tooltips
		
		# Example output: [Icon] +10 Attack Damage (in orange!)
		s += "%s[color=%s]+%s %s[/color]\n" % [stat_icon, stat_color, str(val), formatted_name]
		
	return s
