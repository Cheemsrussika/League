# res://Skills/Effects/Effect_ShootProjectile.gd
extends SkillEffect
class_name Effect_ShootProjectile

@export var projectile_scene: PackedScene
@export var speed: float = 800.0
@export var effects_to_apply: Array[SkillEffect] = []

func on_execute(caster: Node2D, skill_level: int, target_data: Dictionary, _ref: Resource) -> void:
	# 1. Ask the pool for a projectile
	var proj = ProjectilePool.get_projectile(projectile_scene)
	
	var target_pos = target_data.get("target_position", caster.get_global_mouse_position())
	
	# --- DYNAMIC RANGE LIMIT ---
	var actual_range = _ref.cast_range
	if "is_auto_attack" in _ref and _ref.is_auto_attack and caster.has_method("get_total"):
		actual_range = caster.get_total(Unit.Stat.RANGE)
	
	var direction = (target_pos - caster.global_position).normalized()
	
	# 2. Move it to the caster BEFORE waking it up fully
	proj.global_position = caster.global_position
	
	# 3. Call the setup function! (This is what resets _distance_traveled to 0.0)
	if proj.has_method("setup"):
		proj.setup(caster, skill_level, effects_to_apply, direction, speed, actual_range * 2.5, _ref)
