extends Panel

var current_items: Array[ItemData] = []
@export var forge_slot_scene: PackedScene 

@onready var tier_containers = {
	ItemData.Tier.BOOTS:      $ScrollContainer/VBox/BootsRow,
	ItemData.Tier.BASIC:      $ScrollContainer/VBox/BasicRow,
	ItemData.Tier.EPIC:       $ScrollContainer/VBox/EpicRow,
	ItemData.Tier.LEGENDARY:  $ScrollContainer/VBox/LegendaryRow,
}

# --- NEW: Double-click tracking variables ---
var selected_item: ItemData = null
var last_click_time: int = 0
const DOUBLE_CLICK_TIME_MS: int = 400 # Milliseconds allowed between clicks

func _ready():
	visible = false
	
func open_forge(opened: bool):
	visible = opened
	var backpack_ui = get_tree().root.find_child("BackpackPanel", true, false)
	if backpack_ui:
		backpack_ui.visible = opened 

func _get_active_forge_zone() -> Area2D:
	var player = GameManager.player_champion
	if not is_instance_valid(player): return null
	
	var interaction_area = player.get_node_or_null("InteractionArea")
	if interaction_area:
		for area in interaction_area.get_overlapping_areas():
			if area.is_in_group("forge_zone"):
				return area 
	return null

func _input(event):
	if event.is_action_pressed("open_forge"): 
		if not visible:
			var active_forge = _get_active_forge_zone()
			if active_forge:
				current_items = active_forge.available_items
				open_forge(true)
				populate_forge()
				
			else:
				DevMenu.add_log("You must be at an Anvil to craft!")
		else:
			open_forge(false)

func populate_forge():
	for container in tier_containers.values():
		for child in container.get_children():
			child.queue_free()
			
	for item in current_items:
		if not tier_containers.has(item.item_tier): continue
		if item.recipe.is_empty(): continue 
		
		var slot = forge_slot_scene.instantiate()
		tier_containers[item.item_tier].add_child(slot)
		
		if slot.has_method("setup"):
			slot.setup(item)
			
		slot.pressed.connect(_on_item_clicked.bind(item))

# --- REFACTORED: Single vs Double Click Logic ---
func _on_item_clicked(target_item: ItemData):
	var current_time = Time.get_ticks_msec()
	
	# If they click the exact same item within 400ms, it's a double-click!
	if target_item == selected_item and (current_time - last_click_time) < DOUBLE_CLICK_TIME_MS:
		_attempt_craft(target_item)
	else:
		# Otherwise, treat it as a single-click to view stats
		selected_item = target_item
		last_click_time = current_time
		_show_item_info(target_item)

# --- NEW: Function to display item details ---
func _show_item_info(item: ItemData):
	DevMenu.add_log("Selected item in Forge: %s" % item.item_name)
	
	# TODO: Add your UI updates here just like you did in the Shop!
	# Example: %ItemDetails.text = get_item_stats_string(item)
	# Example: %RecipeList.update_recipe_icons(item.recipe)

# --- REFACTORED: The actual crafting function ---
func _attempt_craft(target_item: ItemData):
	if not _get_active_forge_zone():
		DevMenu.add_log("Crafting failed: You walked too far from the Forge!")
		visible = false
		return

	var player = GameManager.player_champion
	var backpack = player.get_node_or_null("BackpackComponent")
	if not backpack: return
	if not backpack.can_purchase(target_item):
		return # DevMenu log is handled inside can_purchase
	if player.gold < target_item.cost:
		DevMenu.add_log("Not enough gold to pay the forging fee! Need: %s" % target_item.cost)
		return

	var required_ingredients = {}
	for req_item in target_item.recipe:
		if required_ingredients.has(req_item.item_name):
			required_ingredients[req_item.item_name] += 1
		else:
			required_ingredients[req_item.item_name] = 1

	for req_name in required_ingredients.keys():
		var required_amount = required_ingredients[req_name]
		if not backpack.has_item(req_name, required_amount):
			DevMenu.add_log("Missing ingredient: Need %s x %s" % [required_amount, req_name])
			return

	# If it passes all checks, consume items and gold!
	for req_name in required_ingredients.keys():
		backpack.remove_item(req_name, required_ingredients[req_name])
	
	player.gold -= target_item.cost
	backpack.add_item(target_item, 1)
	
	DevMenu.add_log("Successfully forged: %s!" % target_item.item_name)
