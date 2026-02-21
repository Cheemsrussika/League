extends Unit
class_name Monster

# --- CONFIG ---
@export var aggro_radius: float = 300.0
@export var leash_radius: float = 700.0
@export var patience_time: float = 3.0 # How long they chase outside range before giving up

# --- STATE MACHINE ---
enum State { IDLE, CHASE, RESET }
var current_state: State = State.IDLE

var spawn_position: Vector2
var patience_timer: float = 0.0

func _ready():
	super._ready() # Initialize HP/Stats from Unit
	spawn_position = global_position
	unit_type = UnitType.MONSTER

func _physics_process(delta):
	if is_dead: return
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.CHASE:
			_process_chase(delta)
		State.RESET:
			_process_reset(delta)

# --- STATE LOGIC ---

func _process_idle(delta):
	# Scan for enemies
	var targets = get_tree().get_nodes_in_group("champion")
	for t in targets:
		if global_position.distance_to(t.global_position) < aggro_radius:
			current_target = t
			current_state = State.CHASE
			print("Monster Aggroed!")

func _process_chase(delta):
	if not is_instance_valid(current_target) or current_target.is_dead:
		current_state = State.RESET
		return

	# 1. Check Leash Distance (Distance from SPAWN, not current pos)
	var dist_from_spawn = spawn_position.distance_to(global_position)
	
	if dist_from_spawn > leash_radius:
		# We are too far from home! Start losing patience.
		patience_timer -= delta
		if patience_timer <= 0:
			current_state = State.RESET
			_start_super_heal() # MOBA Logic: Reset = Super Heal
	else:
		# We are inside the zone, reset patience
		patience_timer = patience_time
		
		# Move towards target (Simple AI)
		var direction = global_position.direction_to(current_target.global_position)
		velocity = direction * get_total(Stat.MS)
		move_and_slide()
		
		# Attack logic (reuse your existing combat logic or call execute_combat_logic)
		_attempt_attack()

func _process_reset(delta):
	# MOBA RESET LOGIC:
	# 1. Ignore Player (don't attack)
	# 2. Run straight home
	# 3. Heal rapidly
	
	var dist = global_position.distance_to(spawn_position)
	if dist < 5.0:
		global_position = spawn_position
		current_state = State.IDLE
		velocity = Vector2.ZERO
		_stop_super_heal()
	else:
		var direction = global_position.direction_to(spawn_position)
		# Move faster when resetting (common MOBA mechanic to prevent blocking)
		velocity = direction * (get_total(Stat.MS) * 1.5) 
		move_and_slide()

# --- THE FIX FOR "STALLING" ---
func _attempt_attack():
	if attack_cooldown_timer <= 0 and is_instance_valid(current_target):
		# Simple attack logic
		var damage = get_total(Stat.AD)
		if current_target.has_method("take_damage"):
			current_target.take_damage(damage, "physical", self, false)
			print("Monster attacked for ", damage)
		
		# Reset Cooldown (1.0 / Attack Speed)
		var aps = max(0.1, get_total(Stat.AS))
		attack_cooldown_timer = 1.0 / aps


func take_damage(amount: float, type: String, source: Node, is_crit: bool = false) -> float:
	if current_state == State.RESET:
		return super.take_damage(amount, type, source, is_crit)
	if current_state == State.IDLE:
		current_target = source
		current_state = State.CHASE
		
	last_combat_time = Time.get_ticks_msec()
	return super.take_damage(amount, type, source, is_crit)
func _start_super_heal():
	modify_stat("health_regen", 1000.0) 
	modulate = Color(0.5, 1.0, 0.5) 

func _stop_super_heal():
	modify_stat("health_regen", -1000.0) # Remove buff
	modulate = Color.WHITE
