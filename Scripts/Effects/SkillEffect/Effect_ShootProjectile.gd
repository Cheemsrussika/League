# res://Skills/Effects/Effect_ShootProjectile.gd
extends SkillEffect
class_name Effect_ShootProjectile

@export var projectile_scene: PackedScene
@export var speed: float = 800.0
@export var effect_to_apply: SkillEffect

func on_execute(caster: Node2D, skill_level: int, target_data: Dictionary, _ref: Resource) -> void:
	var proj = projectile_scene.instantiate()
	var target_pos = target_data.get("target_position", caster.get_global_mouse_position())
	
	proj.caster = caster
	proj.skill_level = skill_level
	proj.effect_to_apply = effect_to_apply
	proj.direction = (target_pos - caster.global_position).normalized()
	proj.speed = speed
	proj.range_limit = _ref.cast_range # Grab range from SkillData!
	proj.skill_ref = _ref # PASS THE PASSPORT TO THE PROJECTILE!
	
	caster.get_tree().current_scene.add_child(proj)
	proj.global_position = caster.global_position
