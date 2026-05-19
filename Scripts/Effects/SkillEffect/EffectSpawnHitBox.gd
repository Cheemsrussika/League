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
@export var effects_to_apply: Array[SkillEffect] = []


func on_execute(caster: Node2D, skill_level: int, target_data: Dictionary, _ref: Resource) -> void:
	if not hitbox_scene: return
	
	var hitbox = hitbox_scene.instantiate()
	
	# Apply Logic
	if hitbox.has_method("set"):
		hitbox.set("caster", caster)
		hitbox.set("skill_level", skill_level)
		hitbox.set("effects_to_apply", effects_to_apply) # Pass the array
		hitbox.set("is_persistent", is_persistent)
		hitbox.set("tick_rate", tick_rate)
		hitbox.set("can_hit_teammates", can_hit_teammates)
		hitbox.set("can_hit_structures", can_hit_structures)
	
	var dynamic_length = hitbox_scale
	if _ref and "is_auto_attack" in _ref and _ref.is_auto_attack and caster.has_method("get_total"):
		var actual_range = caster.get_total(Unit.Stat.RANGE)
		var base_melee_range = 175.0 # The range the hitbox was originally drawn for
		dynamic_length = hitbox_scale * (actual_range/1.5 / base_melee_range)
		
	# Scale X (length) dynamically, keep Y (width) at default hitbox_scale
	hitbox.scale = Vector2(dynamic_length, dynamic_length)

	if spawn_at_mouse:
		# Added safety fallback so target_pos is never Nil
		var target_pos = target_data.get("target_position", caster.get_global_mouse_position())
		
		# Ensure the spawn is capped at the skill's cast_range
		var dist = caster.global_position.distance_to(target_pos)
		if _ref and "cast_range" in _ref and dist > _ref.cast_range:
			target_pos = caster.global_position + (target_pos - caster.global_position).normalized() * _ref.cast_range
			
		# Deferred for physics safety
		caster.get_tree().current_scene.call_deferred("add_child", hitbox)
		hitbox.set_deferred("global_position", target_pos)
	else:
		# Deferred for physics safety (Follows Garen Spin)
		caster.call_deferred("add_child", hitbox) 
	
	# Use the safe handler for BOTH persistent and non-persistent
	_handle_lifetime(hitbox, duration if is_persistent else 0.1)

func _handle_lifetime(hitbox: Node, time: float):
	# Wait for the deferred add_child to put it in the tree
	if not hitbox.is_inside_tree():
		await hitbox.tree_entered
		
	await hitbox.get_tree().create_timer(time).timeout
	
	# THIS is the magic line that stops the crash if the player died!
	if is_instance_valid(hitbox):
		hitbox.queue_free()
