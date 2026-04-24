# res://Skills/Logic/HomingProjectile.gd
extends Area2D

var caster: Node2D
var target: Node2D
var speed: float = 1200.0
var effect_to_apply: SkillEffect
var skill_level: int = 1

func setup(p_caster: Node2D, p_target: Node2D, p_speed: float, p_effect: SkillEffect, p_level: int):
	caster = p_caster
	target = p_target
	speed = p_speed
	effect_to_apply = p_effect
	skill_level = p_level

func _process(delta: float):
	# 1. Cleanup if target dies before it arrives
	if not is_instance_valid(target) or (target.has_method("is_dead") and target.is_dead):
		queue_free()
		return

	# 2. Homing Logic: Calculate direction every frame
	var direction = (target.global_position - global_position).normalized()
	global_position += direction * speed * delta
	
	# 3. Visual Rotation: Point the sprite toward the target
	rotation = direction.angle()

	# 4. Impact Check: Distance-based check is best for high speeds
	if global_position.distance_to(target.global_position) < 30.0:
		_on_impact()

func _on_impact():
	if effect_to_apply:
		# Use the same dictionary keys your system expects
		var context = { 
			"target": target, 
			"target_unit": target,
			"target_position": target.global_position 
		}
		effect_to_apply.on_execute(caster, skill_level, context, null)
	
	queue_free() # Destroy projectile after hitting
