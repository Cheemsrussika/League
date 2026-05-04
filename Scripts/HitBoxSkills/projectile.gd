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

# --- NEW SETUP FUNCTION ---
func setup(p_caster: Node2D, p_level: int, p_effects: Array, p_dir: Vector2, p_speed: float, p_range: float, p_ref: Resource):
	caster = p_caster
	skill_level = p_level
	effects_to_apply = p_effects
	direction = p_dir
	speed = p_speed
	range_limit = p_range
	skill_ref = p_ref
	
	# CRITICAL: Reset this so the reused bullet can fly again!
	_distance_traveled = 0.0 

func _physics_process(delta: float) -> void:
	var move_step = direction * speed * delta
	global_position += move_step
	_distance_traveled += move_step.length()
	
	if _distance_traveled >= range_limit:
		# SEND BACK TO POOL INSTEAD OF queue_free()
		ProjectilePool.call_deferred("return_projectile", self)

func _on_body_entered(body: Node2D) -> void:
	if body == caster or not body is Unit or body.is_dead: return
	if body.team == caster.team: return 

	# Execute ALL effects in the array
	var context = {"target_unit": body, "target": body}
	for effect in effects_to_apply:
		if effect:
			effect.on_execute(caster, skill_level, context, skill_ref)
	
	# SEND BACK TO POOL INSTEAD OF queue_free()
	ProjectilePool.call_deferred("return_projectile", self)
