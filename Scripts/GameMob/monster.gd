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
# NEW: Movement Styles
enum MovementType { SMOOTH, HOPPING }
@export_group("Movement Style")
@export var movement_type: MovementType = MovementType.SMOOTH
@export var hop_rest_time: float = 0.6  # How long the slime sits still
@export var hop_jump_time: float = 0.2  # How fast the actual jump is
@export var hop_speed_multiplier: float = 2.0
var hop_timer: float = 0.0
var is_hopping: bool = false

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
var dir_names = ["Right", "Down", "Left", "Up"]
var current_facing: String = "Down"
#When you are ready, all you have to do is change dir_names to
# ["Right", "DownRight", "Down", "DownLeft", "Left", "UpLeft", "Up", "UpRight"],
# change 4.0 to 8.0, and change % 4 to % 8. The code will automatically adapt!
# --- REFS ---
var my_camp: MonsterCamp = null 
var hop_direction: Vector2 = Vector2.ZERO
# --- UI NODES ---
@onready var health_bar: ProgressBar = $HealthBar
@onready var patience_bar: ProgressBar = $PatienceBar
@onready var separation_area = $SeparationArea
# --- STATE ---
# --- STATE ---
# --- STATE ---
enum State { IDLE, COMBAT, RESET, LOCKED, ATTACKING }
var current_state: State = State.IDLE

enum AttackPhase { NONE, WINDUP, LUNGING, RECOVERY }
var current_attack_phase: AttackPhase = AttackPhase.NONE

# NEW: Attack Type Selection
enum AttackType { MELEE, PROJECTILE, AOE }
@export var attack_type: AttackType = AttackType.MELEE

@export_group("Dynamic Attack")
@export var lunge_speed: float = 600.0
@export var max_lunge_range: float = 150.0 # Tell it exactly how far to go!
@export var recovery_time: float = 0.5
@export_group("Ranged / AoE Settings")
@export var attack_scene: PackedScene # Slot your Projectile or AoE scene here
@export var attack_effect: SkillEffect   # Slot your Damage SkillEffect resource here
@export var projectile_speed: float = 600.0

var phase_timer: float = 0.0
var lunge_direction: Vector2 = Vector2.ZERO

# (Keep your existing variables below this: spawn_position, current_patience, etc.)

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
	elif base_stats.has("attack_range"):
		base_stats["attack_range"]=attack_range
	exp_reward *= scaler
	gold_reward *= scaler
	inventory = $InventoryComponent if has_node("InventoryComponent") else null
	
	recalculate_stats()
	# 4. Apply the changes
	current_health = get_total(Stat.HP)

	scale = Vector2.ONE * (1.0 + (level * 0.05))
	spawn_position = global_position

func _ready():
	super._ready()
	add_to_group("unit")
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
		health_bar.hide()

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
# 1. RESET VELOCITY EACH FRAME
	velocity = Vector2.ZERO
	match current_state:
		State.IDLE: _process_idle(delta)
		State.COMBAT: _process_combat(delta)
		State.RESET: _process_reset(delta)
		State.LOCKED: _process_locked(delta)
		State.ATTACKING: _process_attacking(delta)

# 2. APPLY MOVEMENT STYLE (HOPPING LOGIC)
	if current_state != State.ATTACKING and movement_type == MovementType.HOPPING:
		var intended_velocity = velocity 
		
		if intended_velocity.length() > 0 or is_hopping:
			hop_timer -= delta
			if is_hopping:
				velocity = hop_direction * (get_total(Stat.MS) * hop_speed_multiplier)
				
				if hop_timer <= 0:
					is_hopping = false
					
					# NEW: Determine how long to rest based on the current state!
					if current_state == State.RESET: # (Use whatever your return/heal state is named)
						hop_timer = 0.1 # Panic rest! Almost instantly jump again
					else:
						hop_timer = hop_rest_time # Normal rest from the Inspector
			else:
				velocity = Vector2.ZERO 
				if hop_timer <= 0:
					is_hopping = true
					hop_timer = hop_jump_time 
					hop_direction = intended_velocity.normalized()
		else:
			hop_timer = 0.0
			is_hopping = false

	# 3. APPLY SEPARATION & MOVE
	if current_state in [State.COMBAT, State.RESET, State.ATTACKING]:
		var sep = _get_separation_vector()
		velocity += sep * 150.0 
		move_and_slide()
		
	_handle_animations(delta) # Pass delta here for the idle timer!
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

	# 1. Grab the distance to the target early!
	var target_dist = global_position.distance_to(current_target.global_position)
	
	# 2. Check if the player ran too far away (We multiply by 1.5 so it doesn't instantly drop aggro if they step 1 pixel out of bounds)
	var is_target_too_far = target_dist > (aggro_radius * 1.5)

	# THE PIT CHECK
	var am_i_home = true
	if protect_home_only:
		am_i_home = global_position.distance_to(spawn_position) <= leash_radius
	
	# --- FIXED PATIENCE LOGIC ---
	# Drain patience if pulled too far from home OR if the target runs too far away
	if not am_i_home or is_target_too_far:
		current_patience -= delta
		if patience_bar: patience_bar.show()
	else:
		# Monster is safe at home AND the target is close enough
		current_patience = move_toward(current_patience, patience_time, delta * 2.0)
		# HIDE BAR IF FULL
		if current_patience >= patience_time and patience_bar:
			patience_bar.hide()
			
	if patience_bar: patience_bar.value = current_patience
	
	if current_patience <= 0:
		_start_reset()
		return

	# Movement Logic...
	if not is_stationary:
		# We already calculated target_dist above, so we just use it here!
		if target_dist > attack_range: 
			velocity = global_position.direction_to(current_target.global_position) * get_total(Stat.MS)
	
	_attempt_attack()

func aggro_onto(target):
	if current_state == State.LOCKED or is_dead:
		return
		
	current_target = target
	current_state = State.COMBAT
	_stop_super_heal()
	
	# Optional: Show a "!" effect
	_spawn_floating_text(0, "!", false) # Assuming your text handles strings
func _process_reset(_delta):
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
	if attack_cooldown_timer > 0 or current_state == State.ATTACKING: return
	if movement_type == MovementType.HOPPING and is_hopping: return
	if is_instance_valid(current_target):
		var dist = global_position.distance_to(current_target.global_position)
		if dist <= attack_range: 
			
			# 1. Lock into attack state
			current_state = State.ATTACKING
			current_attack_phase = AttackPhase.WINDUP
			phase_timer = attack_damage_delay # The windup time
			
			# 2. Calculate and SAVE the lunge direction
			lunge_direction = global_position.direction_to(current_target.global_position)
			
			# 3. Play directional attack animation
			var angle = lunge_direction.angle()
			if angle < 0: angle += TAU
			var slice_size = TAU / 4.0 
			var index = int(round(angle / slice_size)) % 4 
			current_facing = dir_names[index]
			
			if anim: anim.play("attack_" + current_facing)
			
			
func _process_attacking(delta):
	phase_timer -= delta
	
	match current_attack_phase:
		AttackPhase.WINDUP:
			velocity = Vector2.ZERO # Stand still while preparing
			if phase_timer <= 0:
				# Windup done! Start the action.
				current_attack_phase = AttackPhase.LUNGING
				
				# NEW: Auto-calculate the exact duration using Time = Distance / Speed
				phase_timer = max_lunge_range / lunge_speed
				
				# --- FIRE PROJECTILE OR AOE ---
				if attack_type == AttackType.PROJECTILE:
					_spawn_projectile()
				elif attack_type == AttackType.AOE:
					_spawn_aoe()

		AttackPhase.LUNGING:
			if attack_type == AttackType.MELEE:
				# --- MELEE LUNGE LOGIC ---
				velocity = lunge_direction * lunge_speed 
				if is_instance_valid(current_target) and not current_target.is_dead:
					var hit_distance = 20
					if global_position.distance_to(current_target.global_position) <= hit_distance:
						current_target.take_damage(get_total(Stat.AD), "physical", self)
						current_attack_phase = AttackPhase.RECOVERY
						phase_timer = recovery_time
						velocity = Vector2.ZERO 
			else:
				# --- RANGED FOLLOW-THROUGH ---
				# Monster stands still to hold its shooting/casting pose
				velocity = Vector2.ZERO
			
			if phase_timer <= 0 and current_attack_phase == AttackPhase.LUNGING:
				current_attack_phase = AttackPhase.RECOVERY
				phase_timer = recovery_time
				velocity = Vector2.ZERO

		AttackPhase.RECOVERY:
			velocity = Vector2.ZERO
			if phase_timer <= 0:
				current_state = State.COMBAT
				current_attack_phase = AttackPhase.NONE
				var aps = max(0.1, get_total(Stat.AS))
				attack_cooldown_timer = 1.0 / aps
				# --- NEW: RESET HOPPING STATE ---
				# Force the slime to sit still on the ground after an attack
				# so it doesn't smoothly slide!
				is_hopping = false
				hop_timer = hop_rest_time
				
				
				
func _spawn_projectile():
	if not attack_scene or not is_instance_valid(current_target): return
	
	var proj = attack_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	
	# Position and Data mapping based on your Projectile.gd
	proj.global_position = global_position
	proj.direction = global_position.direction_to(current_target.global_position)
	proj.caster = self
	proj.speed = projectile_speed
	proj.skill_level = 1
	
	# THE FIX: Tell Godot this array is specifically an Array[SkillEffect]
	if attack_effect:
		proj.effects_to_apply = [attack_effect] as Array[SkillEffect]
func _spawn_aoe():
	if not attack_scene or not is_instance_valid(current_target): return
	
	var aoe = attack_scene.instantiate()
	get_tree().current_scene.add_child(aoe)
	
	# Spawn the AoE directly ON the target's current position
	aoe.global_position = current_target.global_position
	aoe.caster = self
	aoe.skill_level = 1
	
	# Pass the SkillEffect to the AoE zone
	if attack_effect:
		aoe.effects_to_apply = [attack_effect]
		
		
func _start_reset():
	current_target = null
	current_state = State.RESET
	_start_super_heal()

func take_damage(amount: float, type: String, source: Node, is_crit: bool = false, category: String = "attack") -> Dictionary:
	
	# --- ANTI-FRIENDLY FIRE SAFETY NET ---
	# If the source is a unit, and we are on the same team, take NO damage and DO NOT aggro!
	if is_instance_valid(source) and "team" in source:
		if source.team == self.team:
			return {"health_lost": 0, "mitigated": amount}

	if current_state == State.LOCKED:
		return {"health_lost": 0, "mitigated": 0}
		
	# Auto-Aggro (Keep this)
	if (current_state == State.IDLE or current_state == State.RESET) and is_instance_valid(source):
		current_target = source
		current_state = State.COMBAT
		_stop_super_heal()
		if my_camp:
			my_camp.alert_pack(source, self)
	
	var receipt = super.take_damage(amount, type, source, is_crit, category)

	var flash_tween = create_tween()
	sprite.modulate = Color(1.0, 0.0, 0.1) 
	flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.15) 
	
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

		health_bar.max_value = get_total(Stat.HP)
		health_bar.value = current_health
		if(health_bar.max_value==health_bar.value):
			health_bar.hide()
		else:
			health_bar.show()

func _start_super_heal():
	if not is_super_healing:
		is_super_healing = true
		modulate = Color(0.5, 1.0, 0.5)

func _stop_super_heal():
	if is_super_healing:
		is_super_healing = false
		modulate = Color.WHITE
		heal_tick_timer = 0.0
# For MONSTER:
func die(killer):
	if is_dead: return 
	is_dead = true 
	
	$CollisionShape2D.set_deferred("disabled", true)
	# process_mode is safely gone from here!
	
	if health_bar: health_bar.hide()
	if patience_bar: patience_bar.hide()
	
	if is_instance_valid(killer):
		if killer.has_method("add_gold"): killer.add_gold(gold_reward)
		if killer.has_method("gain_experience"): killer.gain_experience(exp_reward)
		if killer is Unit: killer.on_kill_trigger(self) 
		
	emit_signal("unit_died", self)
	
	# --- NEW: PLAY DEATH ANIMATION ---
	# Check if we have an animation player and if the "death" animation exists
	if anim and anim.has_animation("death"):
		anim.play("death")
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 1.0) # Fades out over 1 second
		tween.tween_callback(queue_free)
		await anim.animation_finished
		
	# --- FADE OUT AND DELETE ---
	# This will only run AFTER the animation finishes (or immediately if there is no animation)


var idle_break_timer: float = 0.0
func _handle_animations(delta: float):
	if not anim: return
	
	# 1. ATTACK STATE OVERRIDE
	if current_state == State.ATTACKING:
		# NEW: If the attack lunge is over and we are recovering, force Idle!
		if current_attack_phase == AttackPhase.RECOVERY:
			if anim.current_animation == "" or not anim.current_animation.begins_with("idle_"):
				anim.play("idle_Up")
		return
		
	# 2. UPDATE FACING DIRECTION (if moving)
	var speed = velocity.length()
	if speed > 5.0:
		var angle = velocity.angle()
		if angle < 0: angle += TAU
		var slice_size = TAU / 4.0
		var index = int(round(angle / slice_size)) % 4
		current_facing = dir_names[index]
		idle_break_timer = 0.0 # Reset random idle twitches
		
	# 3. CHOOSE ANIMATION BASED ON PHASE
	if movement_type == MovementType.HOPPING:
		if is_hopping:
			# Phase 1: Mid-air hop! Play your full 1.0s walk animation.
			anim.play("walk_" + current_facing)
		else:
			# Phase 2: Resting on the ground. Play Idle!
			if anim.current_animation == "" or not anim.current_animation.begins_with("idle_"):
				anim.play("idle_Up")
	else:
		# (Standard smooth movement logic for other monsters)
		if speed > 5.0:
			anim.play("walk_" + current_facing)
		else:
			if anim.current_animation == "" or not anim.current_animation.begins_with("idle_"):
				anim.play("idle_" + current_facing)
			
			# Random idle twitches for smooth movers
			idle_break_timer -= delta
			if idle_break_timer <= 0:
				idle_break_timer = randf_range(3.0, 5.0)
				if randf() > 0.3: anim.play("idle_Up")
