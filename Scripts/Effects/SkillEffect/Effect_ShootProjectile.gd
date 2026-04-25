# res://Skills/Effects/Effect_ShootProjectile.gd
extends SkillEffect
class_name Effect_ShootProjectile

@export var projectile_scene: PackedScene
@export var speed: float = 800.0
## THE FIX: Change to Array
@export var effects_to_apply: Array[SkillEffect] = []

func on_execute(caster: Node2D, skill_level: int, target_data: Dictionary, _ref: Resource) -> void:
	var proj = projectile_scene.instantiate()
	var target_pos = target_data.get("target_position", caster.get_global_mouse_position())
	
	proj.set("caster", caster)
	proj.set("skill_level", skill_level)
	# Inject the Array
	proj.set("effects_to_apply", effects_to_apply)
	proj.set("direction", (target_pos - caster.global_position).normalized())
	proj.set("speed", speed)
	proj.set("range_limit", _ref.cast_range)
	proj.set("skill_ref", _ref)
	
	caster.get_tree().current_scene.add_child(proj)
	proj.global_position = caster.global_position
