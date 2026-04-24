# res://Skills/Effects/Effect_SpawnDirectional.gd
extends SkillEffect
class_name Effect_SpawnDirectional

@export_group("Hitbox Settings")
@export var hitbox_scene: PackedScene
@export var hitbox_scale: float = 1.0
## If false, it scan once and deletes. If true, it stays for 'duration'.
@export var is_persistent: bool = false
@export var duration: float = 0.2 # Short duration for a sword poke
@export var tick_rate: float = 0.1

@export_group("Filters")
@export var can_hit_teammates: bool = false
@export var can_hit_structures: bool = false

@export_group("Application")
@export var damage_effect: SkillEffect

func on_execute(caster: Node2D, level: int, target_data: Dictionary, _ref: Resource) -> void:
	if not hitbox_scene: return
	
	# 1. Get the direction from caster to mouse
	var target_pos = target_data.get("target_position", caster.get_global_mouse_position())
	var direction = (target_pos - caster.global_position).normalized()
	
	# 2. Spawn the hitbox
	var hitbox = hitbox_scene.instantiate()
	caster.add_child(hitbox)
	
	# Use local position ZERO so it stays perfectly centered on the caster
	# Since it is a child, (0,0) is exactly where the caster is.
	hitbox.position = Vector2.ZERO 
	
	# Apply rotation relative to the caster
	hitbox.rotation = direction.angle()
	hitbox.scale = Vector2(hitbox_scale, hitbox_scale)
	# 4. Inject Logic (Matches SkillHitbox.gd requirements)
	hitbox.set("caster", caster)
	hitbox.set("skill_level", level)
	hitbox.set("effect_to_apply", damage_effect)
	hitbox.set("is_persistent", is_persistent)
	hitbox.set("tick_rate", tick_rate)
	
	# 5. Inject Filters
	hitbox.set("can_hit_teammates", can_hit_teammates)
	hitbox.set("can_hit_structures", can_hit_structures)
	
	# 6. Handle Lifetime
	if is_persistent:
		_handle_lifetime(hitbox, duration)
	else:
		_handle_lifetime(hitbox,0.1)

func _handle_lifetime(hitbox: Node, time: float):
	await hitbox.get_tree().create_timer(time).timeout
	if is_instance_valid(hitbox):
		hitbox.queue_free()
