extends Panel

@export var all_items: Array[ItemData]
@export var shop_slot_scene: PackedScene 

@onready var tier_containers = {
	ItemData.Tier.CONSUMABLE: $ScrollContainer/VBox/Consumable,
	ItemData.Tier.BOOTS:      $ScrollContainer/VBox/Boots2,
	ItemData.Tier.STARTER:    $ScrollContainer/VBox/StaterRow,
	ItemData.Tier.BASIC:      $ScrollContainer/VBox/BasicRow,
	ItemData.Tier.EPIC:       $ScrollContainer/VBox/EpicRow,
	ItemData.Tier.LEGENDARY:  $ScrollContainer/VBox/LegendaryRow,
}

func _ready():
	visible = false
	# Wait one frame to ensure GameManager is ready
	await get_tree().process_frame
	populate_shop()

func _input(event):
	if event.is_action_pressed("p"): 
		# Check if we are allowed to open it first!
		if not visible:
			if _is_player_in_shop_zone():
				open_shop()
			else:
				print("You must be at a shop to open the catalog!")
		else:
			close_shop()
func open_shop():
	visible = true
	# Close the backpack if it's open so they don't overlap
	var backpack_ui = get_tree().root.find_child("BackpackPanel", true, false)
	if backpack_ui:
		backpack_ui.visible = true # Actually, in many games, opening Shop OPENS backpack too!
		# If you want them to occupy different sides, just let them both be visible.
		# If you want them to SWAP, use: backpack_ui.visible = false

func close_shop():
	visible = false

func _is_player_in_shop_zone() -> bool:
	var player = GameManager.player_champion
	if not is_instance_valid(player): return false
	
	var interaction_area = player.get_node_or_null("InteractionArea")
	if interaction_area:
		for area in interaction_area.get_overlapping_areas():
			if area.is_in_group("shop_zone"):
				return true
	return false
	
func populate_shop():
	# Clear old items
	for container in tier_containers.values():
		if container:
			for child in container.get_children():
				child.queue_free()
				
	# Create new items
	for item in all_items:
		# Safety check: does this tier exist in our dictionary?
		if not tier_containers.has(item.item_tier): continue
		
		var slot = shop_slot_scene.instantiate()
		tier_containers[item.item_tier].add_child(slot)
		
		if slot.has_method("setup"):
			slot.setup(item)
			
		# CONNECT THE SIGNAL HERE
		# This tells ShopPanel to run '_on_item_clicked' when the button is pressed
		#slot.pressed.connect(_on_item_clicked.bind(item))

func _on_item_double_clicked(item: ItemData):
	var player = GameManager.player_champion
	if not is_instance_valid(player):
		return

	# --- Zone Check (Keep this exactly as you had it!) ---
	var in_shop_zone = false
	var interaction_area = player.get_node_or_null("InteractionArea")
	
	if interaction_area:
		for area in interaction_area.get_overlapping_areas():
			if area.is_in_group("shop_zone"):
				in_shop_zone = true
				break
	
	if not in_shop_zone:
		print("You are too far from the shop to buy anything!")
		return
	# -----------------------

	# --- NEW: RPG Purchase Logic ---
	# 1. Look for the Backpack, NOT the Equipment Inventory
	var backpack = player.get_node_or_null("BackpackComponent")
	if not backpack: 
		print("Error: Player has no backpack!")
		return

	# 2. Check if they have the money
	if player.gold < item.cost:
		print("Not enough gold for ", item.item_name)
		return

	# 3. Try to add the item to the backpack FIRST
	# (add_item returns the amount that couldn't fit. 0 means it all fit!)
	var leftover = backpack.add_item(item, 1)

	if leftover == 0:
		# 4. If it successfully went into the bag, take their gold!
		player.gold -= item.cost
		print("Purchased ", item.item_name, " into backpack!")
	else:
		print("Your backpack is full! Cannot buy ", item.item_name)
