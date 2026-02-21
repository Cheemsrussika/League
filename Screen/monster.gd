extends Unit
class_name Monster

# --- CONFIG ---
@export_group("AI Settings")
@export var is_stationary: bool = false
@export var protect_home_only: bool = true 
@export var aggro_radius: float = 300.0
@export var leash_radius: float = 600.0 
@export var patience_time: float = 5.0 
@export var return_delay: float = 2.0 
@export_group("Combat Settings")
@export var attack_range: float = 175.0  
@export var attack_damage_delay: float = 0.3

# --- REFS ---
var my_camp: MonsterCamp = null 

# --- UI NODES ---
@onready var health_bar: ProgressBar = $HealthBar
@onready var patience_bar: ProgressBar = $PatienceBar
@onready var separation_area = $SeparationArea
# --- STATE ---
enum State { IDLE, COMBAT, RESET, LOCKED }
var current_state: State = State.IDLE

var spawn_position: Vector2
var current_patience: float = 0.0
var is_super_healing: bool = false
var lock_timer: float = 0.0
var heal_tick_timer: float = 0.0


func initialize_stats(level: int):
	# Scale: +10% stats per level
	var scaler = 1.0 + ((level - 1) * 0.10)
	
	# 1. Update Health
	attack_range += randf_range(-25.0, 25.0)
	if base_stats.has("health"):
		base_stats["health"] *= scaler
	elif base_stats.has("max_health"):
		base_stats["max_health"] *= scaler
		
	# 2. Update Damage
	if base_stats.has("attack_damage"):
		base_stats["attack_damage"] *= scaler
	elif base_stats.has("damage"):
		base_stats["damage"] *= scaler
	#elif base_stats.has("attack_range"):
		#base_stats["attack_range"]=attack_range
	exp_reward *= scaler
	gold_reward *= scaler
	
	# 4. Apply the changes
	current_health = get_total(Stat.HP)

	scale = Vector2.ONE * (1.0 + (level * 0.05))
	spawn_position = global_position

func _ready():
	super._ready()
	unit_type = UnitType.MONSTER
	spawn_position = global_position
	current_patience = patience_time
	
	if get_parent() is MonsterCamp:
		my_camp = get_parent()

	# Safety Check for Stats
	if get_total(Stat.AS) <= 0:
		base_stats["attack_speed"] = 0.65
		current_health = get_total(Stat.HP)

	# FIX 1: Configure HP Bar Max Value
	if health_bar:
		health_bar.max_value = get_total(Stat.HP) # <--- FIX: Match Bar size to HP
		health_bar.value = current_health
		health_bar.show() # Ensure it's visible

	if patience_bar: 
		patience_bar.hide()
		patience_bar.max_value = patience_time

func _physics_process(delta):
	if is_dead: return
	
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
		
	# HEAL TICK
	if is_super_healing:
		heal_tick_timer -= delta
		if heal_tick_timer <= 0:
			heal_tick_timer = 0.25 
			var heal_amount = get_total(Stat.HP) * 0.10 
			receive_heal(heal_amount)
			
	# 1. RESET VELOCITY EACH FRAME
	velocity = Vector2.ZERO
	match current_state:
		State.IDLE: _process_idle(delta)
		State.COMBAT: _process_combat(delta)
		State.RESET: _process_reset(delta)
		State.LOCKED: _process_locked(delta)
	# 3. APPLY SEPARATION & MOVE (Only call move_and_slide ONCE)
	if current_state == State.COMBAT or current_state == State.RESET:
		var sep = _get_separation_vector()
		velocity += sep * 150.0 # Push force
		move_and_slide()

# --- STATE LOGIC ---
func _get_separation_vector() -> Vector2:
	var push_vector = Vector2.ZERO
	var neighbors = separation_area.get_overlapping_areas()
	if neighbors.size() > 0:
		for area in neighbors:
			# We want a vector pointing AWAY from the neighbor
			var dir = area.global_position.direction_to(global_position)
			# The closer they are, the harder they push
			push_vector += dir
			
		return push_vector.normalized()
	return Vector2.ZERO
	
func _process_idle(_delta):
	pass

func _process_combat(delta):
	if not is_instance_valid(current_target) or current_target.is_dead:
		_start_reset()
		return

	# THE PIT CHECK (STILL HERE!)
	var am_i_home = false
	if my_camp:
		am_i_home = my_camp.is_source_allowed(self)
	else:
		am_i_home = global_position.distance_to(spawn_position) <= leash_radius
	
	# Patience Logic
	if not am_i_home:
		current_patience -= delta
		if patience_bar: patience_bar.show()
	else:
		current_patience = move_toward(current_patience, patience_time, delta * 2.0)
		# HIDE BAR IF FULL
		if current_patience >= patience_time and patience_bar:
			patience_bar.hide()
			
	if patience_bar: patience_bar.value = current_patience
	
	if current_patience <= 0:
		_start_reset()
		return

	# Movement Logic (Just set velocity, don't move_and_slide here)
	if not is_stationary:
		var target_dist = global_position.distance_to(current_target.global_position)
		if target_dist > attack_range - 20.0: 
			velocity = global_position.direction_to(current_target.global_position) * get_total(Stat.MS)
	
	_attempt_attack()


func alert_pack(target_unit, caller_monster):
	# Loop through all children of the Camp
	for child in get_children():
		# Check if it's a monster and NOT the one who called for help
		if child is Monster and child != caller_monster:
			# Only alert them if they aren't already fighting
			if child.current_state != Monster.State.COMBAT:
				child.aggro_onto(target_unit)
func aggro_onto(target):
	if current_state == State.LOCKED or is_dead:
		return
		
	current_target = target
	current_state = State.COMBAT
	_stop_super_heal()
	
	# Optional: Show a "!" effect
	_spawn_floating_text(0, "!", false) # Assuming your text handles strings
func _process_reset(delta):
	var dist = global_position.distance_to(spawn_position)
	
	if dist < 15.0: # Increased threshold slightly for smoother arrival
		global_position = spawn_position
		current_state = State.LOCKED
		lock_timer = return_delay
		current_patience = patience_time 
		if patience_bar: patience_bar.hide()
		_stop_super_heal()
		velocity = Vector2.ZERO
	else:
		# Just set velocity
		velocity = global_position.direction_to(spawn_position) * (get_total(Stat.MS) * 2.0)
		if current_health < get_total(Stat.HP):
			_start_super_heal()
func _process_locked(delta):
	lock_timer -= delta
	# Ensure patience stays full while locked
	current_patience = patience_time 
	
	if lock_timer <= 0:
		current_state = State.IDLE

# --- ATTACK & DAMAGE ---

func _attempt_attack():
	if attack_cooldown_timer > 0: return
	if is_instance_valid(current_target):
		var dist = global_position.distance_to(current_target.global_position)
		if dist <= attack_range: 
			current_target.take_damage(get_total(Stat.AD), "physical", self)
			var aps = max(0.1, get_total(Stat.AS))
			attack_cooldown_timer = 1.0 / aps

func _start_reset():
	current_target = null
	current_state = State.RESET
	_start_super_heal()

func take_damage(amount: float, type: String, source: Node, is_crit: bool = false, category: String = "attack") -> Dictionary:
	if current_state == State.LOCKED:
		return {"health_lost": 0, "mitigated": 0}
		
	# Auto-Aggro (Keep this)
	if (current_state == State.IDLE or current_state == State.RESET) and is_instance_valid(source):
		current_target = source
		current_state = State.COMBAT
		_stop_super_heal()
		if my_camp:
			my_camp.alert_pack(source, self)
	
	# REMOVE the "Fair Fight" block that calls _start_super_heal()
	
	var receipt = super.take_damage(amount, type, source, is_crit, category)
	_update_health_bar() 
	_spawn_floating_text(receipt["health_lost"], type, is_crit)
	return receipt

# --- HELPERS ---

func receive_heal(amount: float):
	if is_dead: return
	var old_health = current_health
	current_health = min(current_health + amount, get_total(Stat.HP))
	
	var actual_heal = current_health - old_health
	if actual_heal > 0:
		_update_health_bar()
		_spawn_floating_text(actual_heal, "heal", false)

func _spawn_floating_text(value: float, type: String, is_crit: bool):
	if value <= 0: return
	if FLOATING_TEXT_SCENE:
		var text = FLOATING_TEXT_SCENE.instantiate()
		get_tree().current_scene.add_child(text)
		text.start(value, global_position + Vector2(0, -50), type, is_crit)

func _update_health_bar():
	if health_bar:
		# Ensure max_value is always correct (in case stats change)
		health_bar.max_value = get_total(Stat.HP)
		health_bar.value = current_health

func _start_super_heal():
	if not is_super_healing:
		is_super_healing = true
		modulate = Color(0.5, 1.0, 0.5)

func _stop_super_heal():
	if is_super_healing:
		is_super_healing = false
		modulate = Color.WHITE
		heal_tick_timer = 0.0
func die(killer):
	if is_dead: return 
	is_dead = true # Set to true so we don't die twice!
	
	# 1. Disable Physics
	$CollisionShape2D.set_deferred("disabled", true)
	process_mode = PROCESS_MODE_DISABLED 
	if health_bar: health_bar.hide()
	if patience_bar: patience_bar.hide()
	
	# 3. Reward the Killer
	if is_instance_valid(killer):
		if killer.has_method("add_gold"):
			killer.add_gold(gold_reward)
		if killer.has_method("gain_experience"):
			killer.gain_experience(exp_reward)
	emit_signal("unit_died", self) 
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(queue_free)
	queue_free()
	super.die(killer) # Call parent Unit.die for global events
