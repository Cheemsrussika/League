extends Node
class_name BackpackComponent

signal backpack_changed

@export var max_slots: int = 36 # RPGs need lots of space!
@export var max_stack_size: int = 99

# This will hold dictionaries: {"item": ItemData, "amount": int}
var slots: Array = [] 

func _ready():
	# Initialize the backpack with empty slots (null)
	slots.resize(max_slots)
	slots.fill(null)

# --- ADDING ITEMS ---
func add_item(new_item: ItemData, amount: int = 1) -> int:
	var amount_left = amount

	# Step 1: Try to add to an existing stack of the same item
	for i in range(max_slots):
		if slots[i] != null and slots[i].item.item_name == new_item.item_name:
			var space_left = max_stack_size - slots[i].amount
			if space_left > 0:
				var add_amt = min(space_left, amount_left)
				slots[i].amount += add_amt
				amount_left -= add_amt
				
				if amount_left <= 0:
					backpack_changed.emit()
					get_tree().call_group("shop_buttons", "update_affordability")
					return 0 # All items successfully added!

	# Step 2: If we still have items left, find an empty slot
	for i in range(max_slots):
		if slots[i] == null:
			# We found an empty slot! Put the rest of the stack here.
			# We duplicate the item so it doesn't share references with global DB
			slots[i] = { "item": new_item.duplicate(true), "amount": amount_left }
			backpack_changed.emit()
			
			return 0 

	# If we get here, the backpack is completely full and we couldn't fit everything
	backpack_changed.emit()
	return amount_left 

# --- REMOVING ITEMS ---
func remove_item(item_name: String, amount: int) -> bool:
	var amount_to_remove = amount
	
	# First, verify we actually have enough to remove (for crafting checks)
	if count_item(item_name) < amount:
		return false 

	# Go backwards through the inventory to remove from the smallest stacks first
	for i in range(max_slots - 1, -1, -1):
		if slots[i] != null and slots[i].item.item_name == item_name:
			if slots[i].amount >= amount_to_remove:
				slots[i].amount -= amount_to_remove
				amount_to_remove = 0
			else:
				amount_to_remove -= slots[i].amount
				slots[i].amount = 0
				
			# If the stack reaches 0, clear the slot completely
			if slots[i].amount <= 0:
				slots[i] = null
				
			if amount_to_remove <= 0:
				backpack_changed.emit()
				return true
				
	return false
# 1. FIXED: The check for the Shop/Forge
func can_purchase(item: ItemData) -> bool:
	if item.is_unique_item:
		# Loop through 'slots', not 'items'
		for slot_data in slots:
			# Check if slot has data, then check the 'item' key inside the dictionary
			if slot_data != null and slot_data.item.item_name == item.item_name:
				DevMenu.add_log("You already own a %s!" % item.item_name)
				return false
	return true
	
# --- HELPER: COUNT ITEMS ---
func count_item(item_name: String) -> int:
	var total = 0
	for slot in slots:
		if slot != null and slot.item.item_name == item_name:
			total += slot.amount
	return total

# --- HELPER: SWAPPING (For UI Drag & Drop) ---
func swap_slots(index_a: int, index_b: int):
	var temp = slots[index_a]
	slots[index_a] = slots[index_b]
	slots[index_b] = temp
	backpack_changed.emit()
	
# Add this to BackpackComponent.gd
func has_item(target_name: String, required_amount: int) -> bool:
	var count = 0
	for slot_data in slots:
		if slot_data != null and slot_data.item.item_name == target_name:
			count += slot_data.amount
			if count >= required_amount:
				return true
	return false
# --- SAVE/LOAD SYSTEM ---
func get_save_data() -> Array:
	var save_array = []
	for slot in slots:
		if slot != null:
			# We save a dictionary containing the ID and the amount
			save_array.append({"id": slot.item.item_id, "amount": slot.amount})
		else:
			save_array.append(null)
	return save_array

func load_save_data(saved_array: Array):
	slots.fill(null) # Clear backpack
	
	for i in range(max_slots):
		if i < saved_array.size() and saved_array[i] != null:
			var saved_dict = saved_array[i]
			var item_resource = ItemDB.get_item_resource(saved_dict["id"])
			if item_resource:
				slots[i] = {
					"item": item_resource.duplicate(true),
					"amount": int(saved_dict["amount"])
				}
				
	backpack_changed.emit()
