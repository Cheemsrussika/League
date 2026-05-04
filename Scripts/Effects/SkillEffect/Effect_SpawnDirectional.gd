# res://Skills/Effects/Effect_SpawnDirectional.gd
extends SkillEffect
class_name Effect_SpawnDirectional

@export_group("Hitbox Settings")
@export var hitbox_scene: PackedScene
@export var hitbox_scale: float = 1.0
@export var is_persistent: bool = false
@export var duration: float = 0.2 
@export var tick_rate: float = 0.1

@export_group("Filters")
@export var can_hit_teammates: bool = false
@export var can_hit_structures: bool = false

@export_group("Application")
## Array of effects applied in the direction of the cast
@export var effects_to_apply: Array[SkillEffect] = []

func on_execute(caster: Node2D, level: int, target_data: Dictionary, _ref: Resource) -> void:
	if not hitbox_scene: return
	
	var target_pos = target_data.get("target_position", caster.get_global_mouse_position())
	var direction = (target_pos - caster.global_position).normalized()
	
	var hitbox = hitbox_scene.instantiate()
	caster.add_child(hitbox) 
	
	hitbox.position = Vector2.ZERO 
	hitbox.rotation = direction.angle()
	# --- DYNAMIC RANGE SCALING ---

	var dynamic_length = hitbox_scale
	if "is_auto_attack" in _ref and _ref.is_auto_attack and caster.has_method("get_total"):
		var actual_range = caster.get_total(Unit.Stat.RANGE)
		var base_melee_range = 175.0 # The range the hitbox was originally drawn for
		dynamic_length = hitbox_scale * (actual_range/1.5 / base_melee_range)
		
	# Scale X (length) dynamically, keep Y (width) at default hitbox_scale
	hitbox.scale = Vector2(dynamic_length, hitbox_scale)
	
	# Match plural naming
	hitbox.set("caster", caster)
	hitbox.set("skill_level", level)
	hitbox.set("effects_to_apply", effects_to_apply)
	hitbox.set("is_persistent", is_persistent)
	hitbox.set("tick_rate", tick_rate)
	hitbox.set("can_hit_teammates", can_hit_teammates)
	hitbox.set("can_hit_structures", can_hit_structures)
	
	_handle_lifetime(hitbox, duration if is_persistent else 0.1)

func _handle_lifetime(hitbox: Node, time: float):
	await hitbox.get_tree().create_timer(time).timeout
	if is_instance_valid(hitbox):
		hitbox.queue_free()
