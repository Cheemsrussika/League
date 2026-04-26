extends Control

@onready var target_slot = $VBoxContainer/TargetItemSlot
@onready var components_container = $VBoxContainer/ComponentsContainer
@onready var desc_label = $VBoxContainer/DescriptionLabel
@onready var buy_button = $VBoxContainer/BuyButton

@onready var builds_into_container = $VBoxContainer/BuildsIntoContainer


var current_preview_item: ItemData = null

# MAKE SURE YOU DRAG YOUR ITEM BUTTON SCENE INTO THIS IN THE INSPECTOR!
@export var component_slot_scene: PackedScene 

func _ready():
	buy_button.pressed.connect(_on_buy_button_pressed)

func view_recipe(item: ItemData):
	if not item: return
	current_preview_item = item
	
	# 1. Clear old layouts (Both Upgrades and Ingredients)
	for child in components_container.get_children():
		child.queue_free()
	for child in builds_into_container.get_children():
		child.queue_free()
		
	# --- NEW: 2. Populate "Builds Into" Row ---
	_populate_builds_into(item)
	
	# 3. Setup Target Item (Row 2 now)
	if target_slot.has_method("setup"):
		target_slot.setup(item)
		
	# 4. Populate Ingredients (Row 3 now)
	if item.recipe and item.recipe.size() > 0:
		for component in item.recipe:
			var slot = component_slot_scene.instantiate()
			components_container.add_child(slot)
			if slot.has_method("setup"):
				slot.setup(component)

	# 5. Update Text & Button
	_update_description(item)
	buy_button.text = "Buy (" + str(item.cost) + "G)"
	
	
	
func _populate_builds_into(target_item: ItemData):
	# Grab the shop panel to access the main list of all items
	var shop = get_tree().get_first_node_in_group("shop_panel")
	if not shop or not "all_items" in shop: return
	
	# Check every item in the game
	for potential_upgrade in shop.all_items:
		if potential_upgrade.recipe and potential_upgrade.recipe.size() > 0:
			# Does this potential upgrade require our target_item?
			for ingredient in potential_upgrade.recipe:
				if ingredient.item_name == target_item.item_name:
					# Yes! Spawn it in the top row.
					var slot = component_slot_scene.instantiate()
					builds_into_container.add_child(slot)
					if slot.has_method("setup"):
						slot.setup(potential_upgrade)
					break # Break the inner loop, move to the next potential upgrade

func _update_description(item: ItemData):
	var text = ""
	
	# 1. First Line: Item Name and Price
	text += "[b][font_size=20]%s[/font_size][/b]  [color=gold]%dG[/color]\n" % [item.item_name, item.cost]
	text += "[color=gray]--------------------------------------[/color]\n"
	
	# 2. Base Stats (Auto-fetched from your Dictionary)
	if item.stats and not item.stats.is_empty():
		for key in item.stats:
			var val = item.stats[key]
			var stat_name = key.replace("_", " ").capitalize()
			text += "[color=lightgreen]+%s %s[/color]\n" % [str(val), stat_name]
	
	# 3. The Description "Box"
	if item.get("description") and item.description != "":
		text += "\n" # Space between stats and passive
		# We use a background color tag to create a visual "box" for the text
		text += "[bgcolor=#1a1c23][color=#d1d1d1]"
		
		# Adding slight indentation so the text doesn't touch the very edge of the box
		text += "[indent]"
		text += "\n" + item.description + "\n"
		text += "[/indent]"
		
		text += "[/color][/bgcolor]"
		
	desc_label.text = text

func _on_buy_button_pressed():
	if current_preview_item:
		var shop = get_tree().get_first_node_in_group("shop_panel")
		# Ensure your ShopPanel script has this function!
		if shop and shop.has_method("_on_item_double_clicked"):
			shop._on_item_double_clicked(current_preview_item)
