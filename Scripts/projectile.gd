# res://Skills/Projectiles/Projectile.gd
extends Area2D

var caster: Node2D
var effect_to_apply: SkillEffect
var skill_ref: Resource # ADD THIS: To hold your SkillData (the "Passport")
var skill_level: int
var speed: float = 800.0
var direction: Vector2 = Vector2.ZERO
var range_limit: float = 1000.0

var _distance_traveled: float = 0.0

func _physics_process(delta: float) -> void:
	var move_step = direction * speed * delta
	global_position += move_step
	_distance_traveled += move_step.length()
	
	if _distance_traveled >= range_limit:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body == caster: return
	if not body is Unit or body.is_dead: return
	if body.team == caster.team: return 

	if body.has_method("take_damage"):
		var context = {"target_unit": body}
		# FIX: Pass skill_ref instead of null!
		effect_to_apply.on_execute(caster, skill_level, context, skill_ref)
		
		queue_free()
