extends Node
class_name AIInputComponent

@export var champion: Champion
@export var detection_range: float = 200.0

# --- ITEM BUILD SYSTEM ---
@export_group("Item AI")
@export var starting_items: Array[ItemData] 
@export var target_build: Array[ItemData]   
var shopping_timer: float = 1.0 

enum State { IDLE, CHASE, ATTACK, RETREAT, SHOPPING } #
var current_state: State = State.IDLE

func _ready():
	if not champion and get_parent() is Champion:
		champion = get_parent()
	call_deferred("_equip_starting_items")

func _physics_process(delta):
	if not is_instance_valid(champion) or champion.is_dead: return
	_decide_logic()
	
	if current_state == State.SHOPPING:
		_move_to_shop(delta)
	else:
		champion.execute_combat_logic(delta)
	_handle_shopping(delta)

# --- SHOPPING LOGIC ---
func _move_to_shop(delta):
	# Find the shop area in the scene
	var shop = get_tree().get_first_node_in_group("shop_zone")
	if shop:
		var direction = (shop.global_position - champion.global_position).normalized()
		champion.velocity = direction * champion.get_total(Unit.Stat.MS)
		champion.move_and_slide()
func _equip_starting_items():
	if not champion.inventory: return
	for item in starting_items:
		champion.inventory.add_item(item.duplicate(true))

func _handle_shopping(delta):
	shopping_timer += delta
	if shopping_timer < 1.0: return
	shopping_timer = 0.0
	
	if target_build.is_empty(): return
	var next_item = target_build[0]
	if champion.gold >= next_item.cost and _is_in_shop_zone():
		_buy_item(next_item)

func _buy_item(item_data: ItemData):
	champion.gold -= item_data.cost
	champion.inventory.add_item(item_data.duplicate(true))
	target_build.remove_at(0)
	# print(champion.name, " bought ", item_data.item_name)
	
func _should_go_to_shop() -> bool:
	if target_build.is_empty(): return false
	var next_item = target_build[0]
	if champion.gold >= next_item.cost:
		if _is_in_shop_zone():
			return false 
		return true
	return false
	
func _is_in_shop_zone() -> bool:
	var interaction_area = champion.get_node_or_null("InteractionArea")
	if interaction_area:
		for area in interaction_area.get_overlapping_areas():
			if area.is_in_group("shop_zone"):
				return true
	return false
	
# --- COMBAT LOGIC ---
func _decide_logic():
	if _should_go_to_shop():
		current_state = State.SHOPPING
		return
	var target = _find_closest_enemy()
	champion.current_target = target
	
	if target:
		# --- NEW DISTANCE LOGIC ---
		var dist = _get_distance_to_target_edge(target)
		
		# Use Unit.Stat instead of Champion.Stat for safety
		var attack_range = champion.get_total(Unit.Stat.RANGE)
		
		if dist <= attack_range:
			current_state = State.ATTACK
		else:
			current_state = State.CHASE
	else:
		current_state = State.IDLE

# Helper function to find the edge of the Hurtbox
func _get_distance_to_target_edge(target: Node2D) -> float:
	var hurtbox = target.get_node_or_null("HurtBox") # Make sure your Area2D is named exactly this
	
	if hurtbox and hurtbox is Area2D:
		# This finds the closest point on the HurtBox shape to the AI
		var shape_owner = hurtbox.get_child(0) # The CollisionShape2D
		if shape_owner and shape_owner.shape:
			# For simplicity with Circles/Rects, we calculate distance to the center 
			# and subtract a "radius" estimate, or just use the center of the Area2D
			return champion.global_position.distance_to(hurtbox.global_position) - 20.0 # -20 compensates for body size
			
	# Fallback to root if no HurtBox found
	return champion.global_position.distance_to(target.global_position)

func _find_closest_enemy() -> Node2D:
	var closest_score = 99999.0
	var closest_target = null
	# Fixed Group Name: You used "unit" in Minion.gd, ensure it matches!
	var potential_targets = get_tree().get_nodes_in_group("unit") 
	
	for target in potential_targets:
		if target == champion: continue 
		if "team" in target and target.team == champion.team: continue 
		if "is_dead" in target and target.is_dead: continue

		var dist = champion.global_position.distance_to(target.global_position)
		if dist > detection_range: continue

		var score = dist 
		# Fix Enum access: UnitType is in Unit class
		if target.unit_type == Unit.UnitType.CHAMPION:
			score -= 200.0 # Focus Champions
			
		if score < closest_score:
			closest_score = score
			closest_target = target
			
	return closest_target
