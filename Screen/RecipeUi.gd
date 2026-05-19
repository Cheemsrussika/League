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
	add_to_group("shop_buttons") # <-- NEW: Listen to the backpack's shout!
	buy_button.pressed.connect(_on_buy_button_pressed)
	
# --- NEW: Triggered whenever the backpack moves an item ---
func update_affordability():
	# If we are currently looking at a recipe...
	if current_preview_item != null:
		# Re-run the description function to update the green/red text instantly!
		_update_description(current_preview_item)

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
	buy_button.text = "Crafting Fee: " + str(item.cost) + "G)"
	
	
	
func _populate_builds_into(target_item: ItemData):
	# Grab the shop panel to access the main list of all items
	var shop = get_tree().get_first_node_in_group("forge_panel")
	if not shop or not "current_items" in shop: return

	# Check every item in the game
	for potential_upgrade in shop.current_items:
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
	
	# 2. Base Stats (Upgraded with StatStyle!)
	if item.stats and not item.stats.is_empty():
		for key in item.stats:
			var val = item.stats[key]
			var stat_name = key.replace("_", " ").capitalize()
			
			# Fetch the icon and color from your helper script
			var icon_bbcode = StatStyle.get_icon_tag(key)
			var color_code = StatStyle.get_color(key)
			
			# Inject the icon and custom color instead of the hardcoded lightgreen
			text += "%s[color=%s]+%s %s[/color]\n" % [icon_bbcode, color_code, str(val), stat_name]
	
	# 3. The Description "Box" (For Lore, Passives, and Drop Locations)
	if item.get("description") and item.description != "":
		text += "\n" # Space between stats and passive
		# We use a background color tag to create a visual "box" for the text
		text += "[bgcolor=#1a1c23][color=#d1d1d1]"
		
		# Adding slight indentation so the text doesn't touch the very edge of the box
		text += "[indent]"
		text += "\n" + item.description + "\n"
		text += "[/indent]"
		
		text += "[/color][/bgcolor]\n"
		
# 4. Recipe Preview (Dynamically colored based on inventory!)
	if item.get("recipe") and not item.recipe.is_empty():
		text += "\n[color=cyan][u]Forging Recipe:[/u][/color]\n"
		
		# Tally up duplicates (e.g., 2x Longsword)
		var reqs = {}
		for req in item.recipe:
			if reqs.has(req.item_name):
				reqs[req.item_name] += 1
			else:
				reqs[req.item_name] = 1
				
		# --- NEW: Get the player's backpack to check inventory ---
		var player = GameManager.player_champion
		var backpack = null
		if is_instance_valid(player):
			backpack = player.get_node_or_null("BackpackComponent")
				
		# Build the text with dynamic colors
		for req_name in reqs:
			var needed_amount = reqs[req_name]
			var has_enough = false
			
			# Check if the backpack exists and has the required amount
			if backpack and backpack.has_item(req_name, needed_amount):
				has_enough = true
				
			# Pick the color based on the check
			var color_code = "green" if has_enough else "red"
			
			# Inject the color code into the string
			text += "- [color=%s]%sx %s[/color]\n" % [color_code, str(needed_amount), req_name]
	# Apply to your RichTextLabel
	# Note: If you renamed it to %ItemDetails earlier, change this to: %ItemDetails.text = text
	desc_label.text = text
	
func _on_buy_button_pressed():
	if current_preview_item:
		var forge = get_tree().get_first_node_in_group("forge_panel")
		
		# We changed the function name to _attempt_craft in the previous step!
		if forge and forge.has_method("_attempt_craft"):
			forge._attempt_craft(current_preview_item)
