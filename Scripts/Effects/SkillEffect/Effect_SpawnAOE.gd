# res://Skills/Effects/Effect_SpawnAOE.gd
extends SkillEffect
class_name Effect_SpawnAOE

@export_group("Hitbox Settings")
@export var hitbox_scene: PackedScene
@export var hitbox_scale: float = 1.0 
@export var is_persistent: bool = false
@export var duration: float = 3.0
@export var tick_rate: float = 0.5

@export_group("Filters")
@export var can_hit_teammates: bool = false
@export var can_hit_structures: bool = false
@export var spawn_at_mouse: bool = false

@export_group("Application")
## The list of effects (Damage, Status, Heal, etc.) applied to targets
@export var effects_to_apply: Array[SkillEffect] = [] 

func on_execute(caster: Node2D, skill_level: int, target_data: Dictionary, _ref: Resource) -> void:
	if not hitbox_scene: return
	
	var hitbox = hitbox_scene.instantiate()
	
	# Inject plural array to match your Hitbox plural variable
	hitbox.set("caster", caster)
	hitbox.set("skill_level", skill_level)
	hitbox.set("effects_to_apply", effects_to_apply) 
	hitbox.set("is_persistent", is_persistent)
	hitbox.set("tick_rate", tick_rate)
	hitbox.set("can_hit_teammates", can_hit_teammates)
	hitbox.set("can_hit_structures", can_hit_structures)
	
	hitbox.scale = Vector2(hitbox_scale, hitbox_scale)
	
	if spawn_at_mouse:
		var target_pos = target_data.get("target_position")
		var dist = caster.global_position.distance_to(target_pos)
		if dist > _ref.cast_range:
			target_pos = caster.global_position + (target_pos - caster.global_position).normalized() * _ref.cast_range
		
		# Add to scene tree so it doesn't move with the caster
		caster.get_tree().current_scene.add_child(hitbox)
		hitbox.global_position = target_pos
	else:
		# Add as child so it follows the caster (e.g., Garen Spin)
		caster.add_child(hitbox)
	
	_handle_lifetime(hitbox, duration if is_persistent else 0.1)

func _handle_lifetime(hitbox: Node, time: float):
	await hitbox.get_tree().create_timer(time).timeout
	if is_instance_valid(hitbox):
		hitbox.queue_free()
