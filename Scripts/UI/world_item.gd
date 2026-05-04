extends Area2D
class_name WorldItem

## A WorldItem is an item lying on the ground.
## It registers itself with nearby InteractionArea detectors.
## Scene needs: Sprite2D ($Sprite), CollisionShape2D, optionally Label ($NameLabel)

signal picked_up(world_item: WorldItem)

@onready var sprite: Sprite2D = $Sprite
@onready var name_label: Label = $NameLabel  # Optional — can be null

var item_data: ItemData = null
var item_amount: int = 1

# Small bob animation state
var _bob_offset: float = 0.0
var _bob_speed: float = 2.0
var _bob_range: float = 3.0
var _base_y: float = 0.0

func _ready() -> void:
	_base_y = position.y
	# Add to group so InteractionArea can find all WorldItems nearby
	add_to_group("world_items")

func _process(delta: float) -> void:
	# Gentle bobbing so items are visible on the ground
	_bob_offset += delta * _bob_speed
	if sprite:
		sprite.position.y = sin(_bob_offset) * _bob_range

# -----------------------------------------------------------
# Called by LootTableComponent (or any spawner) after instantiation
# -----------------------------------------------------------
func setup(data: ItemData, amount: int = 1) -> void:
	item_data = data
	item_amount = amount

	if data is LootBagData:
		var bag = data as LootBagData
		# Disguise ONLY if there's 1 item and ZERO gold/exp rewards
		if bag.contents.size() == 1 and bag.gold_reward == 0 and bag.exp_reward == 0:
			var single_item = bag.contents[0]
			sprite.texture = single_item.icon
			if name_label: name_label.text = single_item.item_name
		else:
			# Use the default bag icon for multi-item or gold-only bags
			sprite.texture = data.icon if data.icon else preload("res://icon.svg")
			if name_label: name_label.text = "Loot Bag"
	else:
		sprite.texture = data.icon
		if name_label: name_label.text = data.item_name
	if sprite and sprite.texture:
		# Calculate scale to fit inside a 40x40 pixel box
		var target_size = 40.0 
		var current_size = sprite.texture.get_size()
		var scale_factor = target_size / max(current_size.x, current_size.y)
		sprite.scale = Vector2(scale_factor, scale_factor)

# -----------------------------------------------------------
# Actually gives the item to a unit's backpack
# Returns true if successfully picked up
# -----------------------------------------------------------
func try_pickup(unit: Unit) -> bool:
	if item_data == null: return false

	if item_data is LootBagData:
		var bag = item_data as LootBagData
		
		# 1. Give Gold & Exp, then CLEAR them so they aren't double-given
		if bag.gold_reward > 0:
			if unit.has_method("add_gold"): unit.add_gold(bag.gold_reward)
			bag.gold_reward = 0
			
		if bag.exp_reward > 0:
			if unit.has_method("gain_experience"): unit.gain_experience(bag.exp_reward)
			bag.exp_reward = 0
		
		# 2. Unpack items
		@warning_ignore("confusable_local_declaration")
		var backpack = unit.get_node_or_null("BackpackComponent")
		if backpack:
			var remaining_items: Array[ItemData] = []
			for item in bag.contents:
				@warning_ignore("confusable_local_declaration")
				var leftover = backpack.add_item(item, 1)
				if leftover > 0:
					remaining_items.append(item)
			
			# Update the bag with whatever didn't fit
			bag.contents = remaining_items

			if bag.contents.is_empty():
				DevMenu.add_log("[Loot] Bag fully looted!")
				queue_free()
				return true
			else:
				DevMenu.add_log("[Loot] Backpack full! Some items remain.")
				# We return false so the bag stays on the 64x64 grid tile
				return false 

	# --- Standard Single-Item Logic (for items not in bags) ---
	var backpack = unit.get_node_or_null("BackpackComponent")
	# ... (Your existing backpack logic for single items)
	if backpack == null:
		DevMenu.add_log("[WorldItem] Unit has no BackpackComponent: " + unit.name)
		return false

	var leftover = backpack.add_item(item_data, item_amount)

	if leftover == 0:
		# All items were picked up
		picked_up.emit(self)
		queue_free()
		return true
	elif leftover < item_amount:
		# Partially picked up — update remaining amount
		item_amount = leftover
		if name_label:
			name_label.text = item_data.item_name
			if item_amount > 1:
				name_label.text += " x%d" % item_amount
		DevMenu.add_log("[WorldItem] Backpack full — %d %s left on ground." % [leftover, item_data.item_name])
		return false
	else:
		DevMenu.add_log("[WorldItem] Backpack is full, cannot pick up %s." % item_data.item_name)
		return false
