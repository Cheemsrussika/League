# res://Skills/Effects/Effect_SpawnProjectile.gd (Homing)
extends SkillEffect
class_name Effect_HomingProjectile

@export var projectile_scene: PackedScene
@export var speed: float = 1200.0
## THE FIX: Change to Array
@export var effects_to_apply: Array[SkillEffect] = []

func on_execute(caster: Node2D, level: int, target_data: Dictionary, _ref: Resource):
	var target = target_data.get("target_unit")
	if not is_instance_valid(target): return
	
	# 1. Ask the pool for a projectile
	var proj = ProjectilePool.get_projectile(projectile_scene)
	
	proj.global_position = caster.global_position
	
	if proj.has_method("setup"):
		proj.setup(caster, target, speed, effects_to_apply, level)
