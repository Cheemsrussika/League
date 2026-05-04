# res://Skills/Logic/HomingProjectile.gd
extends Area2D

var caster: Node2D
var target: Node2D
var speed: float = 1200.0
var skill_level: int = 1
var effects_to_apply: Array[SkillEffect] = []

func setup(p_caster: Node2D, p_target: Node2D, p_speed: float, p_effects: Array, p_level: int):
	caster = p_caster
	target = p_target
	speed = p_speed
	effects_to_apply = p_effects
	skill_level = p_level

func _process(delta: float):
	if not is_instance_valid(target) or target.is_dead:
		# SEND BACK TO POOL INSTEAD OF queue_free()
		ProjectilePool.call_deferred("return_projectile", self) 
		return

	var direction = (target.global_position - global_position).normalized()
	global_position += direction * speed * delta
	rotation = direction.angle()

	if global_position.distance_to(target.global_position) < 30.0:
		_on_impact()

func _on_impact():
	var context = { 
		"target": target, 
		"target_unit": target,
		"target_position": target.global_position 
	}
	
	# Execute ALL effects
	for effect in effects_to_apply:
		if effect:
			effect.on_execute(caster, skill_level, context, null)
	
	# SEND BACK TO POOL INSTEAD OF queue_free()
	ProjectilePool.call_deferred("return_projectile", self)		
