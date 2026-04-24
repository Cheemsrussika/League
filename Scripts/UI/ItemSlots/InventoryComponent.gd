extends Node
class_name InventoryComponent

signal inventory_changed

@export var max_slots: int = 10
var items: Array[ItemData] = []
var effect_cooldowns: Dictionary = {}

func _process(delta: float):
	var owner_node = get_parent() # The Champion
	if not owner_node: return
	for item in items:
		if item and item.effects:
			for effect in item.effects:
				if effect.has_method("on_update"):
					effect.on_update(owner_node, delta)
# --- NEW: Swap Items (For Drag & Drop) ---
func swap_items(index_a: int, index_b: int):
	var temp = items[index_a]
	items[index_a] = items[index_b]
	items[index_b] = temp
	inventory_changed.emit()


func _ready():
	items.resize(max_slots)
	items.fill(null)

func trigger_item_passive(item: ItemData, trigger_name: String):
	var owner_node = get_parent()
	if item and item.effects:
		for effect in item.effects:
			if effect.has_method(trigger_name):
				effect.call(trigger_name, owner_node)

func trigger_global_event(trigger_name: String, context: Dictionary):
	var owner_node = get_parent()
	var current_time = Time.get_ticks_msec()
	for item in items:
		if item == null: continue 
		for effect in item.effects:
			if effect.has_method(trigger_name):
				if effect.id != "" and effect.cooldown > 0:
					var next_ready_time = effect_cooldowns.get(effect.id, 0.0)
					if current_time < next_ready_time:
						continue 
					effect_cooldowns[effect.id] = current_time + effect.cooldown
				effect.call(trigger_name, owner_node, context)
func request_ui_refresh():
	var owner_node = get_parent()
	if owner_node.has_method("refresh_inventory_ui"):
		owner_node.refresh_inventory_ui()
		inventory_changed.emit()
func add_item(item: ItemData) -> bool:
	for i in range(max_slots):
		if items[i] == null:
			var unique_item = item.duplicate(true) 
			items[i] = unique_item
			trigger_item_passive(unique_item,"on_equip")
			if unique_item.effects:
				for effect in unique_item.effects:
					if effect.has_method("get_tooltip_extra"):
						unique_item.active_effect_instance = effect
						break
			var parent = get_parent()
			if parent.has_method("recalculate_stats"):
				parent.recalculate_stats()
			inventory_changed.emit()
			return true
	return false

func remove_item(index: int):
	if index >= 0 and index < items.size():
		var item = items[index]
		if item:
			trigger_item_passive(item,"on_unequip")
		items[index] = null
		inventory_changed.emit()

func try_purchase(player, item_to_buy: ItemData) -> bool:
	# 1. Calculate the current price based on what we already own
	var final_price = item_to_buy.cost
	var components_indices: Array[int] = [] 
	
	for component in item_to_buy.recipe:
		var found = false
		for i in range(items.size()):
			if items[i] != null and items[i].item_name == component.item_name and not i in components_indices:
				final_price -= component.cost
				components_indices.append(i)
				found = true
				break
	
	# 2. Check for Unique Passive duplicates
	if _would_cause_duplicate_unique(item_to_buy, components_indices):
		print("Cannot purchase: Unique item conflict!")
		return false

	# 3. IF WE CAN AFFORD THE FULL ITEM
	if player.gold >= final_price:
		var empty_slots = items.count(null)
		var slots_freed = components_indices.size()
		
		if empty_slots == 0 and slots_freed == 0:
			print("Inventory full!")
			return false
			
		player.gold -= final_price
		for idx in components_indices:
			var component_to_remove = items[idx]
			if component_to_remove:
				trigger_item_passive(component_to_remove, "on_unequip")
			items[idx] = null
		
		add_item(item_to_buy)
		return true
	else:
		if item_to_buy.recipe.is_empty():
			print("Not enough gold for ", item_to_buy.item_name)
			return false
			
		print("Not enough for ", item_to_buy.item_name, ". Checking recipe...")
		for component in item_to_buy.recipe:
			var already_owned = false
			for i in range(items.size()):
				if items[i] != null and items[i].item_name == component.item_name:
					already_owned = true
					break
			if not already_owned:
				var success = try_purchase(player, component)
				if success:
					return true 
		return false
func _would_cause_duplicate_unique(new_item: ItemData, ingredients_indices: Array[int]) -> bool:
	var unique_ids_found: Array[String] = []

	if new_item.effects != null:
		for eff in new_item.effects:
			if eff.is_unique:
				unique_ids_found.append(eff.id)
	if unique_ids_found.is_empty():
		return false
	for i in range(items.size()):
		if items[i] == null:
			continue
		if i in ingredients_indices:
			continue
		if items[i].effects != null:
			for eff in items[i].effects:
				if eff.is_unique and eff.id in unique_ids_found:
					print("Purchase Blocked: Duplicate Unique ID '", eff.id, "' found.")
					return true
	return false
