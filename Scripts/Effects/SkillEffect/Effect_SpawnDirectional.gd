# res://Skills/Effects/Effect_SpawnDirectional.gd
extends SkillEffect
class_name Effect_SpawnDirectional

@export_group("Hitbox Settings")
@export var hitbox_scene: PackedScene
@export var hitbox_scale: float = 1.0
@export var spawn_offset: float = 20.0 
@export var is_persistent: bool = false
@export var duration: float = 0.2 
@export var tick_rate: float = 0.1
@export var flipped: bool = false # Controlled from your inspector

@export_group("Filters")
@export var can_hit_teammates: bool = false
@export var can_hit_structures: bool = false

@export_group("Application")
@export var effects_to_apply: Array[SkillEffect] = []

func on_execute(caster: Node2D, level: int, target_data: Dictionary, _ref: Resource) -> void:
	if not hitbox_scene: return
	
	var target_pos = target_data.get("target_position", caster.get_global_mouse_position())
	var direction = (target_pos - caster.global_position).normalized()
	
	var hitbox = hitbox_scene.instantiate()
	
	# --- FIXED: ACCURATE RATIO SCALING ---# --- FIXED: BASE MULTIPLIER SCALING ---
	var scale_factor: float = 1.0
	
	if _ref and "is_auto_attack" in _ref and _ref.is_auto_attack and caster.has_method("get_total"):
		var actual_range = caster.get_total(Unit.Stat.RANGE) # e.g., 175.0
		var base_melee_range = 175.0
		
		if base_melee_range > 0:
			scale_factor = actual_range / base_melee_range/3

	# 1. This is the magic scale factor needed to shrink a 128px canvas down to a 16px game world
	var asset_baseline_scale = 0.125 
	
	# 2. Combine the inspector knob, the weapon range stat ratio, and the asset multiplier together
	var baseline_growth = hitbox_scale * scale_factor * asset_baseline_scale
	
	var final_x_scale = baseline_growth
	var final_y_scale = baseline_growth/2
	
	if flipped:
		final_y_scale = -final_y_scale
		
	# 3. Scale the ROOT node. Now BOTH the sprite and the polygon shrink by 0.125 together!
	hitbox.scale = Vector2(final_x_scale, final_y_scale)
	# Match plural naming
	hitbox.set("caster", caster)
	hitbox.set("skill_level", level)
	hitbox.set("effects_to_apply", effects_to_apply)
	hitbox.set("is_persistent", is_persistent)
	hitbox.set("tick_rate", tick_rate)
	hitbox.set("can_hit_teammates", can_hit_teammates)
	hitbox.set("can_hit_structures", can_hit_structures)
	if _ref is SkillData:
		# Check the checkbox you created on your SkillData resource!
		hitbox.set("is_basic_attack", _ref.is_auto_attack) 
		
		# Keep your category matching based on that auto attack toggle too!
		var core_category = "attack" if _ref.is_auto_attack else "spell"
		hitbox.set("category", core_category)
		hitbox.set("allow_lifesteal", _ref.allow_lifesteal)
		hitbox.set("is_on_hit", _ref.is_on_hit)
		hitbox.set("on_hit_multiplier", _ref.on_hit_multiplier)
	# --- SAFE PARENTING & POSITIONING ---
	caster.call_deferred("add_child", hitbox) 
	
	hitbox.set_deferred("position", direction * spawn_offset) 
	hitbox.set_deferred("rotation", direction.angle())
	
	if hitbox.has_node("AudioStreamPlayer2D"):
		hitbox.get_node("AudioStreamPlayer2D").play()
		
	_handle_lifetime(hitbox, duration if is_persistent else 0.1)

func _handle_lifetime(hitbox: Node, time: float):
	if not hitbox.is_inside_tree():
		await hitbox.tree_entered
		
	await hitbox.get_tree().create_timer(time).timeout
	
	if is_instance_valid(hitbox):
		# Cleaned up cleanup step (removed the late flip lines)
		if hitbox is Area2D:
			hitbox.monitorable = false
			hitbox.monitoring = false
		if hitbox.has_node("AnimatedSprite2D"):
			hitbox.get_node("AnimatedSprite2D").visible = false
		if hitbox.has_node("Sprite2D"):
			hitbox.get_node("Sprite2D").visible = false
			
		if hitbox.has_node("AudioStreamPlayer2D"):
			var audio = hitbox.get_node("AudioStreamPlayer2D")
			if audio.playing:
				await audio.finished
				
		hitbox.queue_free()
