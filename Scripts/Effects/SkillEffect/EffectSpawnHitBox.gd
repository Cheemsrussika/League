# res://Skills/Effects/Effect_SpawnHitbox.gd
extends SkillEffect
class_name Effect_SpawnHitbox

@export_group("Hitbox Settings")
@export var hitbox_scene: PackedScene
## The size multiplier. 1.0 is default, 2.0 is double size.
@export var hitbox_scale: float = 1.0 
@export var is_persistent: bool = false
@export var duration: float = 3.0
@export var tick_rate: float = 0.5
@export_group("Filters")
@export var can_hit_teammates: bool = false
@export var can_hit_structures: bool = false
@export var spawn_at_mouse: bool = false
@export_group("Application")
## The Damage or Status effect to apply to everyone inside
@export var effect_to_apply: SkillEffect 


func on_execute(caster: Node2D, skill_level: int, target_data: Dictionary, _ref: Resource) -> void:
	if not hitbox_scene: return
	
	var hitbox = hitbox_scene.instantiate()
	
	# Apply Logic
	hitbox.set("caster", caster)
	hitbox.set("skill_level", skill_level)
	hitbox.set("effect_to_apply", effect_to_apply)
	hitbox.set("is_persistent", is_persistent)
	hitbox.set("tick_rate", tick_rate)
	
	# Apply Filters
	hitbox.set("can_hit_teammates", can_hit_teammates)
	hitbox.set("can_hit_structures", can_hit_structures)
	
	# Apply Transform
	hitbox.scale = Vector2(hitbox_scale, hitbox_scale)
	
	if spawn_at_mouse:
		var target_pos = target_data.get("target_position")
		# Ensure the spawn is capped at the skill's cast_range
		var dist = caster.global_position.distance_to(target_pos)
		if dist > _ref.cast_range:
			target_pos = caster.global_position + (target_pos - caster.global_position).normalized() * _ref.cast_range
		caster.get_tree().current_scene.add_child(hitbox)
		hitbox.global_position = target_pos
	else:
		caster.add_child(hitbox) # Follows Garen (Spin)
	
	if is_persistent:
		_handle_lifetime(hitbox, duration)
	else:
		# One-shot hitboxes usually delete themselves after one frame/scan
		pass

func _handle_lifetime(hitbox: Node, time: float):
	await hitbox.get_tree().create_timer(time).timeout
	if is_instance_valid(hitbox):
		hitbox.queue_free()
