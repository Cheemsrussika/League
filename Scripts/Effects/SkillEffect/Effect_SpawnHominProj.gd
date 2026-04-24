# res://Skills/Effects/Effect_SpawnProjectile.gd
extends SkillEffect
class_name Effect_HomingProjectile


@export var projectile_scene: PackedScene
@export var speed: float = 1200.0
@export var damage_effect: SkillEffect # The Damage/Status resource

# Inside Effect_SpawnProjectile.gd
func on_execute(caster: Node2D, level: int, target_data: Dictionary, _ref: Resource):
	var target = target_data.get("target_unit")
	if not is_instance_valid(target): 
		print("Projectile Fail: No valid target in target_data")
		return
	
	var proj = projectile_scene.instantiate()
	
	# Alternative: Add to the parent of the caster (the world/map)
	caster.get_parent().add_child(proj)
	
	proj.global_position = caster.global_position
	proj.setup(caster, target, speed, damage_effect, level)
	print("Projectile spawned at: ", proj.global_position)
	
	# Pass all the logic to the projectile
	if proj.has_method("setup"):
		proj.setup(caster, target, speed, damage_effect, level)
