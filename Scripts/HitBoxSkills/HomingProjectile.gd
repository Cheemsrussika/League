# res://Skills/Logic/HomingProjectile.gd
extends Area2D

var caster: Node2D
var target_unit: Node2D      
var target_position: Vector2  
var speed: float = 1200.0
var skill_level: int = 1
var effects_to_apply: Array[SkillEffect] = []
var has_impacted: bool = false

# --- NEW: PIPELINE CLASSIFICATION STORAGE ---
var is_basic_attack: bool = false
var category: String = "spell"
var allow_lifesteal: bool = false
var is_on_hit: bool = false
var on_hit_multiplier: float = 1.0

func _ready() -> void:
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

# THE FIX: Added p_ref to setup signatures to parse skill settings natively
func setup(p_caster: Node2D, p_target_unit, p_target_pos: Vector2, p_speed: float, p_effects: Array, p_level: int, p_ref: Resource = null):
	caster = p_caster
	target_unit = p_target_unit if is_instance_valid(p_target_unit) else null
	target_position = p_target_pos
	speed = p_speed
	effects_to_apply = p_effects
	skill_level = p_level
	has_impacted = false
	
	# --- NEW: PARSE ATTACK LOGIC ---
	if p_ref is SkillData:
		is_basic_attack = p_ref.is_auto_attack
		category = "attack" if p_ref.is_auto_attack else "spell"
		allow_lifesteal = p_ref.allow_lifesteal
		is_on_hit = p_ref.is_on_hit
		on_hit_multiplier = p_ref.on_hit_multiplier

func _process(delta: float):
	if has_impacted: return
	if target_unit != null and not is_instance_valid(target_unit):
		target_unit = null

	if target_unit != null and not target_unit.is_dead:
		target_position = target_unit.global_position

	var direction = (target_position - global_position).normalized()
	global_position += direction * speed * delta
	rotation = direction.angle()

	if global_position.distance_to(target_position) < 30.0:
		_on_impact(target_unit)

func _on_area_entered(other_area: Area2D) -> void:
	if has_impacted: return
	if not is_instance_valid(caster) or not is_instance_valid(other_area): return
	
	var hit_unit = other_area
	if hit_unit.has_method("get_parent") and not hit_unit is Unit:
		hit_unit = hit_unit.get_parent()
		
	if is_instance_valid(hit_unit) and hit_unit is Unit and not hit_unit.is_dead:
		if hit_unit == caster: return 
		if hit_unit.team != caster.team:
			_on_impact(hit_unit)

func _on_impact(hit_unit):
	has_impacted = true
	var final_target = hit_unit if is_instance_valid(hit_unit) else null
	
	# --- FIXED: PACK CONTEXT DATA FOR EFFECT_DAMAGE ---
	var context = { 
		"target": final_target, 
		"target_unit": final_target,
		"target_position": global_position,
		"is_basic_attack": is_basic_attack,
		"category": category,
		"allow_on_hits": is_on_hit,
		"allow_lifesteal": allow_lifesteal,
		"on_hit_mult": on_hit_multiplier
	}
	
	for effect in effects_to_apply:
		if effect:
			# Ensure skill_ref is forwarded to the execution layer
			effect.on_execute(caster, skill_level, context, null)
			
	_return_to_pool()

func _return_to_pool():
	target_unit = null
	caster = null
	ProjectilePool.call_deferred("return_projectile", self)
