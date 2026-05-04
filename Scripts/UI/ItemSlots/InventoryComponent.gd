extends Node
class_name InventoryComponent


signal item_went_on_cooldown(slot_index: int, duration: float)
signal inventory_changed

@export var max_slots: int = 6 # Set to 6 to match your UI!
var items: Array[ItemData] = []
var effect_cooldowns: Dictionary = {}

func _ready():
	items.resize(max_slots)
	items.fill(null)

func _process(delta: float):
	var owner_node = get_parent()
	if not owner_node: return
	for item in items:
		if item and item.effects:
			for effect in item.effects:
				if effect.has_method("on_update"):
					effect.on_update(owner_node, delta)

func swap_items(index_a: int, index_b: int):
	var temp = items[index_a]
	items[index_a] = items[index_b]
	items[index_b] = temp
	inventory_changed.emit()
# --- ADD THIS TO INVENTORYCOMPONENT.GD ---

func use_active_slot(slot_index: int):
	if slot_index < 0 or slot_index >= items.size(): return
	var item = items[slot_index]
	if item == null or not item.effects: return
	
	var owner_node = get_parent()
	var current_time = Time.get_ticks_msec()
	
	for effect in item.effects:
		# Check if this effect is an "Active" ability
		if effect.has_method("on_active_use"):
			# Handle Cooldowns
			if effect.id != "" and effect.cooldown > 0:
				var next_ready_time = effect_cooldowns.get(effect.id, 0.0)
				if current_time < next_ready_time:
					DevMenu.add_log("Item is on cooldown!")
					continue
				# Assuming effect.cooldown is in milliseconds. If it's seconds, multiply by 1000!
				effect_cooldowns[effect.id] = current_time + (effect.cooldown * 1000)
				item_went_on_cooldown.emit(slot_index, effect.cooldown)
			effect.call("on_active_use", owner_node)
			DevMenu.add_log("Used active item: " + item.item_name)
			
			# Optional: Emit a signal if you want the UI slot to show a cooldown sweep animation
			# item_went_on_cooldown.emit(slot_index, effect.cooldown)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory_1"): use_active_slot(0)
	elif event.is_action_pressed("inventory_2"): use_active_slot(1)
	elif event.is_action_pressed("inventory_3"): use_active_slot(2)
	elif event.is_action_pressed("inventory_4"): use_active_slot(3)
	elif event.is_action_pressed("inventory_5"): use_active_slot(4)
	elif event.is_action_pressed("inventory_6"): use_active_slot(5)
	elif event.is_action_pressed("inventory_7"): use_active_slot(6)
# --- TRIGGER FUNCTIONS REMAIN UNCHANGED ---
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

# --- REFACTORED ITEM MANAGEMENT ---
func add_item(item: ItemData) -> bool:
	if _would_cause_duplicate_unique(item):
		DevMenu.add_log("Cannot equip: Unique passive conflict!")
		return false

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
			get_tree().call_group("shop_buttons", "update_affordability")
			return true
	return false

# Changed this to RETURN the ItemData so we can pass it to the Backpack
func remove_item(index: int) -> ItemData:
	if index >= 0 and index < items.size():
		var item = items[index]
		if item:
			trigger_item_passive(item,"on_unequip")
			items[index] = null
			
			var parent = get_parent()
			if parent.has_method("recalculate_stats"):
				parent.recalculate_stats()
				
			inventory_changed.emit()
			get_tree().call_group("shop_buttons", "update_affordability")
			return item
	return null

# Simplified Unique Check (No more ingredient arrays)
func _would_cause_duplicate_unique(new_item: ItemData) -> bool:
	var unique_ids_found: Array[String] = []

	if new_item.effects != null:
		for eff in new_item.effects:
			if eff.is_unique:
				unique_ids_found.append(eff.id)
				
	if unique_ids_found.is_empty():
		return false
		
	for item in items:
		if item == null: continue
		if item.effects != null:
			for eff in item.effects:
				if eff.is_unique and eff.id in unique_ids_found:
					return true
	return false
# --- SAVE/LOAD SYSTEM ---
func get_save_data() -> Array:
	var save_array = []
	for item in items:
		if item != null:
			save_array.append(item.item_id)
		else:
			save_array.append("") # Empty slot
	return save_array

func load_save_data(saved_array: Array):
	# Clear current items safely
	for i in range(max_slots):
		remove_item(i)
		
	for i in range(max_slots):
		if i < saved_array.size() and saved_array[i] != "":
			var item_resource = ItemDB.get_item_resource(saved_array[i])
			if item_resource:
				var unique_item = item_resource.duplicate(true)
				items[i] = unique_item
				trigger_item_passive(unique_item, "on_equip")
				
				# Re-link active effects for the tooltip/use
				if unique_item.effects:
					for effect in unique_item.effects:
						if effect.has_method("get_tooltip_extra"):
							unique_item.active_effect_instance = effect
							break
							
	inventory_changed.emit()
