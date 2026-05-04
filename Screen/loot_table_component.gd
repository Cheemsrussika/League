extends Node
class_name LootTableComponent

## Attach as a child of any Unit (Monster, Minion, Champion, Tower, HarvestableUnit).
## Drop data (drop_items, drop_chances) lives on the PARENT UNIT, not here.
## This component is pure behavior — it just reads, rolls, and spawns.

const WORLD_ITEM_SCENE = preload("res://Scripts/UI/WorldItem.tscn")

@export_group("Drop Settings")
## Max items that can drop in one death. 0 = no limit.
@export var max_drops_per_death: int = 0
## How far items scatter from the death position.
@export var drop_scatter_radius: float = 32.0

var _parent_unit: Unit = null

func _ready() -> void:
	_parent_unit = get_parent() as Unit
	if _parent_unit == null:
		push_error("[LootTableComponent] Parent must be a Unit!")
		return
	_parent_unit.unit_died.connect(_on_unit_died)

# -----------------------------------------------------------
# Fires when parent dies — reads arrays from parent Unit
# -----------------------------------------------------------
func _on_unit_died(_unit: Unit) -> void:
	var items: Array = _parent_unit.get("drop_items") if _parent_unit.get("drop_items") else []
	var chances: Array = _parent_unit.get("drop_chances") if _parent_unit.get("drop_chances") else []

	if items.is_empty(): return

	# 1. Create the MASTER BAG for this death
	var master_bag = LootBagData.new()
	master_bag.item_name = "Loot Bag"
	# Note: We don't add Monster gold here since you said it's handled elsewhere.

	# 2. Roll for each item/sub-bag
	for i in range(items.size()):
		if items[i] == null: continue
		
		# If the roll succeeds for this specific entry
		if randf() <= chances[i]:
			var drop = items[i]
			
			if drop is LootBagData:
				# MERGE: Take the rewards out of the sub-bag and put into master_bag
				master_bag.gold_reward += drop.gold_reward
				master_bag.exp_reward += drop.exp_reward
				# Also take any pre-defined items inside that sub-bag
				master_bag.contents.append_array(drop.contents)
			else:
				# Standard item: just put it in the bag
				master_bag.contents.append(drop)

	# 3. Only spawn if we actually collected something
	if not master_bag.contents.is_empty() or master_bag.gold_reward > 0:
		_spawn_world_item.call_deferred(master_bag, 1, _parent_unit.global_position)

# -----------------------------------------------------------
# Spawns a WorldItem into the scene
# -----------------------------------------------------------
func _spawn_world_item(item: ItemData, amount: int, origin: Vector2) -> void:
	if not WORLD_ITEM_SCENE:
		push_error("[LootTableComponent] WORLD_ITEM_SCENE not set!")
		return

	var world_item = WORLD_ITEM_SCENE.instantiate()
	var offset = Vector2(
		randf_range(-drop_scatter_radius, drop_scatter_radius),
		randf_range(-drop_scatter_radius, drop_scatter_radius)
	)
	get_tree().current_scene.add_child(world_item)
	world_item.global_position = origin + offset
	world_item.setup(item, amount)

# -----------------------------------------------------------
# Editor warning if parent has no drop arrays defined
# -----------------------------------------------------------
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not (get_parent() is Unit):
		warnings.append("LootTableComponent must be a child of a Unit node.")
		return warnings
	var parent = get_parent()
	if not parent.get("drop_items"):
		warnings.append("Parent Unit has no 'drop_items' array — add it to your Unit subclass.")
	if not parent.get("drop_chances"):
		warnings.append("Parent Unit has no 'drop_chances' array — add it to your Unit subclass.")
	return warnings
