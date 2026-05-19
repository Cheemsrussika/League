# res://Skills/Projectiles/Projectile.gd
extends Area2D

var caster: Node2D
var skill_ref: Resource
var skill_level: int
var speed: float = 800.0
var direction: Vector2 = Vector2.ZERO
var range_limit: float = 1000.0
var effects_to_apply: Array[SkillEffect] = []

var _distance_traveled: float = 0.0

# --- NEW: MOBA SYSTEM CONTEXT FIELDS ---
var is_basic_attack: bool = false
var category: String = "spell"
var allow_lifesteal: bool = false
var is_on_hit: bool = false
var on_hit_multiplier: float = 1.0

# --- UPDATED SETUP FUNCTION ---
func setup(p_caster: Node2D, p_level: int, p_effects: Array, p_dir: Vector2, p_speed: float, p_range: float, p_ref: Resource):
	caster = p_caster
	skill_level = p_level
	effects_to_apply = p_effects
	direction = p_dir.normalized() 
	speed = p_speed
	range_limit = p_range
	skill_ref = p_ref
	
	# --- NEW: PARSE ATTACK INFORMATION FROM THE SKILL RESOURCE ---
	if p_ref is SkillData:
		is_basic_attack = p_ref.is_auto_attack
		category = "attack" if p_ref.is_auto_attack else "spell"
		allow_lifesteal = p_ref.allow_lifesteal
		is_on_hit = p_ref.is_on_hit
		on_hit_multiplier = p_ref.on_hit_multiplier
	else:
		# Fallback defaults
		is_basic_attack = false
		category = "spell"
		allow_lifesteal = false
		is_on_hit = false
		on_hit_multiplier = 1.0

	global_rotation = direction.angle() + (PI / 2)
	_distance_traveled = 0.0

func _physics_process(delta: float) -> void:
	var move_step = direction * speed * delta
	global_position += move_step
	_distance_traveled += move_step.length()
	
	if _distance_traveled >= range_limit:
		ProjectilePool.call_deferred("return_projectile", self)

func _on_body_entered(body: Node2D) -> void:
	if body == caster or not body is Unit or body.is_dead: return
	if body.team == caster.team: return 

	# --- FIXED: MERGE AND FORWARD COMBAT ATTRIBUTES ON COLLISION ---
	var context = {
		"target_unit": body, 
		"target": body,
		"target_position": global_position,
		"is_basic_attack": is_basic_attack,  # Enables correct branching in Effect_Damage
		"category": category,                 # Alerts item system of weapon type
		"allow_on_hits": is_on_hit,           # Checked by your Item Passive match statements
		"allow_lifesteal": allow_lifesteal,   # Checked by your unit's health loop
		"on_hit_mult": on_hit_multiplier      
	}
	
	for effect in effects_to_apply:
		if effect:
			effect.on_execute(caster, skill_level, context, skill_ref)
	
	ProjectilePool.call_deferred("return_projectile", self)
