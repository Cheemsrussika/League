extends Area2D
class_name InteractionArea

## Attach as a child of your Champion/Player node.
## Handles:
##   Mode 1 — Keybind: press "interact" to pick up the nearest item
##   Mode 3 — Scroll List: press "open_pickup_list" to open a UI showing
##             all nearby items; player clicks one to pick it up.
##
## Scene needs a CollisionShape2D (set its radius to your pickup range).
## Also needs a PickupListUI node (see PickupListPanel.gd) somewhere in the HUD,
## referenced via the group "pickup_list_panel".

signal nearby_items_changed(items: Array)  # Useful for HUD indicators

@export var pickup_range: float = 80.0  # Should match your CollisionShape radius

# Tracked WorldItems currently in range
var _items_in_range: Array[WorldItem] = []

# Owner unit (set on _ready)
var _owner_unit: Unit = null

func _ready() -> void:
	_owner_unit = get_parent() as Unit
	if _owner_unit == null:
		push_error("[InteractionArea] Must be a child of a Unit!")

	# Connect overlap signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _unhandled_input(event: InputEvent) -> void:
	if _owner_unit == null or _owner_unit.is_dead: return

	# --- MODE 1: Keybind — pick up the single nearest item ---
	if event.is_action_pressed("interact"):
		_pickup_nearest()

	# --- MODE 3: Open scroll list ---
	if event.is_action_pressed("open_pickup_list"):
		_open_pickup_list()

# -----------------------------------------------------------
# MODE 1 — Pick up closest item
# -----------------------------------------------------------
func _pickup_nearest() -> void:
	var nearest = _get_nearest_item()
	if nearest == null:
		DevMenu.add_log("[InteractionArea] No items nearby.")
		return
	nearest.try_pickup(_owner_unit)

func _get_nearest_item() -> WorldItem:
	var closest: WorldItem = null
	var closest_dist: float = INF

	for item in _items_in_range:
		if not is_instance_valid(item): continue
		var d = global_position.distance_to(item.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = item

	return closest

# -----------------------------------------------------------
# MODE 3 — Open the scroll-list pickup panel
# -----------------------------------------------------------
func _open_pickup_list() -> void:
	# Clean stale references
	_items_in_range = _items_in_range.filter(func(i): return is_instance_valid(i))

	if _items_in_range.is_empty():
		DevMenu.add_log("[InteractionArea] No items nearby to list.")
		return

	var panel = get_tree().get_first_node_in_group("pickup_list_panel")
	if panel == null:
		push_error("[InteractionArea] No node in group 'pickup_list_panel' found!")
		return

	# Pass current nearby items to the panel
	panel.open_for_items(_items_in_range, _owner_unit)

# -----------------------------------------------------------
# Called by PickupListPanel when the player selects an item
# -----------------------------------------------------------
func request_pickup(world_item: WorldItem) -> void:
	if not is_instance_valid(world_item): return
	world_item.try_pickup(_owner_unit)

# -----------------------------------------------------------
# Overlap tracking — WorldItem is an Area2D
# -----------------------------------------------------------
func _on_area_entered(area: Area2D) -> void:
	if area is WorldItem and not _items_in_range.has(area):
		_items_in_range.append(area)

		nearby_items_changed.emit(_items_in_range)

func _on_area_exited(area: Area2D) -> void:
	if area is WorldItem:
		_items_in_range.erase(area)
		nearby_items_changed.emit(_items_in_range)

# Some WorldItems might use body if you switch to StaticBody — cover both
func _on_body_entered(_body: Node2D) -> void: pass
func _on_body_exited(_body: Node2D) -> void: pass

func _on_world_item_picked_up(world_item: WorldItem) -> void:
	_items_in_range.erase(world_item)
	nearby_items_changed.emit(_items_in_range)

# -----------------------------------------------------------
# Public helper — lets other systems query what's nearby
# -----------------------------------------------------------
func get_nearby_items() -> Array[WorldItem]:
	_items_in_range = _items_in_range.filter(func(i): return is_instance_valid(i))
	return _items_in_range
