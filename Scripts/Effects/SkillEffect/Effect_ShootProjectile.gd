extends SkillEffect
class_name Effect_ShootProjectile

@export_group("Projectile Base")
@export var projectile_scene: PackedScene
@export var speed: float = 800.0
@export var max_dis_plus:float=100
@export var effects_to_apply: Array[SkillEffect] = []

@export_group("Multi-Shot Settings")
@export var projectile_count: int = 1
## Seconds between shots (Machine Gun style). Set to 0 for instant burst.
@export var burst_delay: float = 0.0

@export_group("Inaccuracy & Bloom")
## The total cone of inaccuracy in degrees. (e.g., 10.0 means +/- 5 degrees of random spray)
@export var spread_angle: float = 0.0 
## Random local distance offset forward/backward and left/right from the caster's center
@export var spawn_scatter: float = 0.0

func on_execute(caster: Node2D, skill_level: int, target_data: Dictionary, _ref: Resource) -> void:
	# Calculate range
	var actual_range = _ref.cast_range+max_dis_plus
	if "is_auto_attack" in _ref and _ref.is_auto_attack and caster.has_method("get_total"):
		actual_range = caster.get_total(Unit.Stat.RANGE)+max_dis_plus

	for i in range(projectile_count):
		# Prevent crashes if the caster dies mid-burst
		if not is_instance_valid(caster):
			break
			
		var target_pos: Vector2
		# FIX: Check for a live unit first. If none, grab the live mouse position!
		if target_data.has("target_unit") and is_instance_valid(target_data["target_unit"]):
			target_pos = target_data["target_unit"].global_position
		else:
			target_pos = caster.get_global_mouse_position()
		
		# Calculate base directions relative to the caster for clean local layout offsets
		var base_direction = (target_pos - caster.global_position).normalized()
		var lateral_direction = base_direction.orthogonal()
		
		# 1. Determine the unique scattered starting position
		var spawn_pos = caster.global_position
		if spawn_scatter > 0.0:
			var forward_offset = randf_range(-spawn_scatter, spawn_scatter)
			var lateral_offset = randf_range(-spawn_scatter, spawn_scatter)
			spawn_pos += (base_direction * forward_offset) + (lateral_direction * lateral_offset)
		
		# 2. Calculate direction from the UNIQUE spawn position to the target.
		var arrow_direction = (target_pos - spawn_pos).normalized()
		
		# 3. Apply optional bloom/inaccuracy relative to that true target line
		if spread_angle > 0.0:
			var random_deviation = randf_range(-spread_angle / 2.0, spread_angle / 2.0)
			arrow_direction = arrow_direction.rotated(deg_to_rad(random_deviation))
		
		# 4. Spawn the projectile with its perfectly accurate vector
		_spawn_projectile(caster, skill_level, arrow_direction, spawn_pos, actual_range, _ref)

		# 5. Burst delay tracking
		if burst_delay > 0 and i < projectile_count - 1:
			await caster.get_tree().create_timer(burst_delay).timeout

func _spawn_projectile(caster, lvl, dir, pos, rng, ref):
	var proj = ProjectilePool.get_projectile(projectile_scene)
	proj.global_position = pos
	
	if proj.has_method("setup"):
		proj.setup(caster, lvl, effects_to_apply, dir, speed, rng * 2.5, ref)
