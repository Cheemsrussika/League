# res://Skills/Effects/Effect_HomingProjectile.gd
extends SkillEffect
class_name Effect_HomingProjectile

@export_group("Projectile Base")
@export var projectile_scene: PackedScene
@export var speed: float = 1200.0
@export var effects_to_apply: Array[SkillEffect] = []
@export var max_range: float = 1000
@export_group("Multi-Shot Settings")
@export var projectile_count: int = 1
@export var burst_delay: float = 0.0

@export_group("Scatter Settings")
@export var spawn_scatter: float = 0.0
# res://Skills/Effects/Effect_HomingProjectile.gd
# ... (Keep your variable headers exactly the same) ...

func on_execute(caster: Node2D, level: int, target_data: Dictionary, _ref: Resource):
	var target = target_data.get("target_unit") 
	var target_pos = target_data.get("target_position", caster.global_position)
	
	if target != null and not is_instance_valid(target):
		target = null
		
	if target == null and not target_data.has("target_position"):
		return
	
	for i in range(projectile_count):
		if not is_instance_valid(caster): 
			break
		
		var active_target = target
		if active_target != null and not is_instance_valid(active_target):
			active_target = null 
		
		var destination = active_target.global_position if active_target != null else target_pos
		var base_direction = (destination - caster.global_position).normalized()
		var lateral_direction = base_direction.orthogonal()
		
		var spawn_pos = caster.global_position
		if spawn_scatter > 0.0:
			var forward_offset = randf_range(-spawn_scatter, spawn_scatter)
			var lateral_offset = randf_range(-spawn_scatter, spawn_scatter)
			spawn_pos += (base_direction * forward_offset) + (lateral_offset * lateral_offset)
			
		var proj = ProjectilePool.get_projectile(projectile_scene)
		proj.global_position = spawn_pos
		
		if proj.has_method("setup"):
			# --- FIXED: PASS THE SKILL REFERENCE AS THE FINAL ARGUMENT ---
			proj.setup(caster, active_target, destination, speed, effects_to_apply, level, _ref)
			
		if burst_delay > 0 and i < projectile_count - 1:
			await caster.get_tree().create_timer(burst_delay).timeout
