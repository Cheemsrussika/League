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
		visible = !visible

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
		slot.pressed.connect(_on_item_clicked.bind(item))

func _on_item_clicked(item: ItemData):
	# 1. Get Player from Manager
	var player = GameManager.player_champion
	if not is_instance_valid(player):
		return

	# --- NEW: Zone Check ---
	var in_shop_zone = false
	# Look for the InteractionArea we discussed adding
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

	var inventory = null
	for child in player.get_children():
		if child is InventoryComponent:
			inventory = child
			break

	if inventory:
		var success = inventory.try_purchase(player, item)
		if success:
			print("Shop: Purchase successful")
