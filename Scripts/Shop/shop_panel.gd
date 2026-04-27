extends Panel

var current_items: Array[ItemData] = []
@export var shop_slot_scene: PackedScene 

@onready var tier_containers = {
	ItemData.Tier.BOOTS:      $Shop/VBox/Boots2,
	ItemData.Tier.CONSUMABLE: $Shop/VBox/Consumable,
	ItemData.Tier.STARTER:    $Shop/VBox/StarterRow,
	# BASIC is moved to Forge as requested!
}

# Keep track of what the player is currently looking at
var selected_item: ItemData = null

func _ready():
	visible = false
	
	# Hide the action panel/buttons initially
	_clear_action_panel()
	
	# Connect the UI buttons
	%BuyButton.pressed.connect(_on_buy_pressed)
	%SellButton.pressed.connect(_on_sell_pressed)
	add_to_group("shop_buttons")
	await get_tree().process_frame
# --- NEW: Refresh UI when items move ---
func update_affordability():
	# If the shop is open and we are looking at an item...
	if visible and selected_item != null:
		# Force the panel to re-check the backpack and player gold!
		_on_item_selected(selected_item)
	
func _get_active_shop_zone() -> Area2D:
	var player = GameManager.player_champion
	if not is_instance_valid(player): return null
	var interaction_area = player.get_node_or_null("InteractionArea")
	if interaction_area:
		for area in interaction_area.get_overlapping_areas():
			if area.is_in_group("shop_zone"): 
				return area # Return the specific merchant!
	return null
func open_shop(opened:bool):
	visible = opened
	# Close the backpack if it's open so they don't overlap
	var backpack_ui = get_tree().root.find_child("BackpackPanel", true, false)
	if backpack_ui:
		backpack_ui.visible = opened # Actually, in many games, opening Shop OPENS backpack too!

func _input(event):
	if event.is_action_pressed("open_shop"):
		if not visible:
			var active_merchant = _get_active_shop_zone()
			if active_merchant:
				# 1. Steal the items from the merchant
				current_items = active_merchant.available_items 
				open_shop(true)
				
				# 3. BUILD THE BUTTONS! (This was the missing link)
				populate_shop() 
				
				_clear_action_panel()
			else:
				print("You must be at the Merchant to open the Shop!")
		else:
			open_shop(false)
			
func populate_shop():
	for container in tier_containers.values():
		for child in container.get_children():
			child.queue_free()
			
	for item in current_items:
		if not tier_containers.has(item.item_tier): continue
		
		var slot = shop_slot_scene.instantiate()
		tier_containers[item.item_tier].add_child(slot)
		if slot.has_method("setup"):
			slot.setup(item)
			
		# SINGLE CLICK now selects the item
		slot.pressed.connect(_on_item_selected.bind(item))

func _is_player_in_zone(zone_group: String) -> bool:
	var player = GameManager.player_champion
	if not is_instance_valid(player): return false
	var interaction_area = player.get_node_or_null("InteractionArea")
	if interaction_area:
		for area in interaction_area.get_overlapping_areas():
			if area.is_in_group(zone_group): return true
	return false

# --- NEW: Action Panel Logic ---

func _clear_action_panel():
	selected_item = null
	%ItemIcon.texture = null
	%ItemDetails.text = "[center][color=gray]Select an item[/color][/center]"
	%BuyButton.disabled = true
	%SellButton.disabled = true
	%BuyButton.text = "Buy"
	%SellButton.text = "Sell"
# --- Inside your ShopPanel.gd ---

func _on_item_selected(item: ItemData):
	selected_item = item
	
	# 1. Update visuals & Buttons
	%ItemIcon.texture = item.icon
	%BuyButton.disabled = false
	%BuyButton.text = "Buy (" + str(item.cost) + "G)"
	
	var player = GameManager.player_champion
	var backpack = player.get_node_or_null("BackpackComponent")
	
	var sell_price = floor(item.cost * 0.5)
	%SellButton.text = "Sell (" + str(sell_price) + "G)"
	
	if backpack and backpack.has_item(item.item_name, 1):
		%SellButton.disabled = false
	else:
		%SellButton.disabled = true

	# ==========================================
	# 3. THE NEW FORMATTED RICHTEXTLABEL INFO
	# ==========================================
	var info_text = "[center][b][color=yellow]%s[/color][/b][/center]\n\n" % item.item_name
	
	# Grabs the item description (Lore, Passive effects, or Drop locations!)
	if item.description != "":
		info_text += "[color=lightgray][i]%s[/i][/color]\n\n" % item.description
		
	# Loops through the dictionary and applies your StatStyle formatting
	if not item.stats.is_empty():
		info_text += "[u]Stats:[/u]\n"
		for stat_key in item.stats:
			var stat_value = str(item.stats[stat_key])
			
			# Turns snake_case ("attack_damage") into Title Case ("Attack Damage")
			var display_name = stat_key.capitalize() 
			
			# Get the formatting from your static class
			var icon_bbcode = StatStyle.get_icon_tag(stat_key)
			var color_code = StatStyle.get_color(stat_key)
			
			# Combines the Icon, Color, Value, and Name into one beautiful line
			info_text += "%s[color=%s]+%s %s[/color]\n" % [icon_bbcode, color_code, stat_value, display_name]
			
	%ItemDetails.text = info_text

# --- BUY & SELL EXECUTION ---

func _on_buy_pressed():
	if not selected_item or not _is_player_in_zone("shop_zone"): return
	
	var player = GameManager.player_champion
	var backpack = player.get_node_or_null("BackpackComponent")
	
	if player.gold < selected_item.cost:
		print("Not enough gold!")
		return

	var leftover = backpack.add_item(selected_item, 1)
	if leftover == 0:
		player.gold -= selected_item.cost
		print("Bought ", selected_item.item_name)
		# Re-select to refresh the Sell button status
		_on_item_selected(selected_item) 
	else:
		print("Backpack full!")

func _on_sell_pressed():
	if not selected_item or not _is_player_in_zone("shop_zone"): return
	
	var player = GameManager.player_champion
	var backpack = player.get_node_or_null("BackpackComponent")
	
	# Safety check: ensure they didn't drop it or equip it
	if backpack.has_item(selected_item.item_name, 1):
		backpack.remove_item(selected_item.item_name, 1)
		
		var sell_price = floor(selected_item.cost * 0.5)
		player.gold += sell_price
		DevMenu.add_log("Sold %s for %s" %[selected_item.item_name,sell_price])
		
		# Refresh the panel to see if they have more to sell
		_on_item_selected(selected_item)
	else:
		DevMenu.add_log("You don't have this item in your backpack!")
