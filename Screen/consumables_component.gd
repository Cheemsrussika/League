extends Node
class_name ConsumablesComponent

signal consumables_changed

@export var max_slots: int = 2 # e.g., Keys D and F or 7 and 8
var items: Array[ItemData] = []
var stacks: Array[int] = []

func _ready():
	items.resize(max_slots)
	items.fill(null)
	stacks.resize(max_slots)
	stacks.fill(0)


# Returns remaining overflow if slot is full
func equip_consumable(item: ItemData, amount: int, slot_index: int) -> int:
	if items[slot_index] == null:
		items[slot_index] = item
		stacks[slot_index] = amount
	elif items[slot_index].item_name == item.item_name: # Simple match check
		# Add to stack (you can add a max_stack_size check here if you want)
		stacks[slot_index] += amount
	else:
		return amount # Slot taken by different item
		
	consumables_changed.emit()
	return 0
# Removes a specific amount from a slot. If amount is -1 (default), it clears the whole stack.
func remove_item(slot_index: int, amount: int = -1) -> void:
	# 1. Safety checks
	if slot_index < 0 or slot_index >= items.size(): 
		return
	if items[slot_index] == null: 
		return
		
	# 2. Subtract the amount
	if amount == -1 or amount >= stacks[slot_index]:
		# Clear the entire slot
		items[slot_index] = null
		stacks[slot_index] = 0
	else:
		# Just reduce the stack size
		stacks[slot_index] -= amount
		
	# 3. Notify the UI to update
	consumables_changed.emit()
# Automatically finds the right slot to put the consumable in!
func add_consumable(item: ItemData, amount: int = 1) -> bool:
	for i in range(max_slots):
		var leftover = equip_consumable(item, amount, i)
		if leftover == 0:
			return true # Successfully added!
			
	return false # Consumable slots are completely full

func use_consumable(slot_index: int):
	if slot_index < 0 or slot_index >= items.size(): return
	var item = items[slot_index]
	if item == null: return
	
	var owner_node = get_parent()
	var was_successfully_used = false # NEW: Track if we should actually delete it
	
	# Trigger the consumable effect
	if item.effects:
		for effect in item.effects:
			if effect.has_method("on_consume"):
				# NEW: Capture the return value!
				var result = effect.call("on_consume", owner_node) 
				if result == true or result == null:
					was_successfully_used = true
	
	# NEW: If the potion blocked us (returned false), stop right here!
	if not was_successfully_used:
		return 
	
	# Reduce Stack
	stacks[slot_index] -= 1
	if stacks[slot_index] <= 0:
		items[slot_index] = null
		stacks[slot_index] = 0
		
	consumables_changed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("consumable_1"): use_consumable(0)
	elif event.is_action_pressed("consumable_2"): use_consumable(1)
	elif event.is_action_pressed("consumable_3"): use_consumable(2)
# --- SAVE/LOAD SYSTEM ---
func get_save_data() -> Array:
	var save_array = []
	for i in range(max_slots):
		if items[i] != null:
			save_array.append({"id": items[i].item_id, "amount": stacks[i]})
		else:
			save_array.append(null)
	return save_array

func load_save_data(saved_array: Array):
	items.fill(null)
	stacks.fill(0)
	
	for i in range(max_slots):
		if i < saved_array.size() and saved_array[i] != null:
			var saved_dict = saved_array[i]
			var item_resource = ItemDB.get_item_resource(saved_dict["id"])
			if item_resource:
				items[i] = item_resource.duplicate(true)
				stacks[i] = int(saved_dict["amount"])
				
	consumables_changed.emit()
