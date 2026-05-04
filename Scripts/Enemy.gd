extends Champion
class_name EnemyChampion

var target: Node2D = null

func _ready():
	super._ready()
	# 1. Find the player automatically
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]

func _physics_process(delta: float) -> void:
	var direction = Vector2.ZERO
	
	# 2. AI LOGIC
	if target:
		# Calculate direction toward player
		direction = (target.global_position - global_position).normalized()
		
		# Optional: Stop if too close (Attack Range logic)
		if global_position.distance_to(target.global_position) < 50.0:
			direction = Vector2.ZERO
			# attack_target() # Future logic
	
	# 3. SEND COMMAND TO BASE CLASS
	# The enemy uses the EXACT same movement stats (MS) as the player!
	command_move(direction)

	# 4. REGEN
	handle_regeneration(delta)
