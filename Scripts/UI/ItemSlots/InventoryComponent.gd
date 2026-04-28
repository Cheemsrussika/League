extends Node
class_name InventoryComponent

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
