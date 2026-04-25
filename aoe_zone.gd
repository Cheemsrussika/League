# res://Scripts/Skills/Logic/SkillAoEZone.gd
extends Area2D

var caster: Node2D # Changed to Node2D for safety
var skill_level: int = 1
var effects_to_apply: Array[SkillEffect] = []
var tick_rate: float = 0.25
var duration: float = 3.0
var is_persistent: bool = true
var can_hit_teammates: bool = false
var can_hit_structures: bool = false

var _timer: float = 0.0

func _ready() -> void:
	# Scale and setup is handled by the Spawner
	if is_persistent:
		get_tree().create_timer(duration).timeout.connect(queue_free)
	else:
		# Wait for physics to wake up then hit once
		await get_tree().physics_frame
		_apply_damage()
		queue_free()

func _process(delta: float) -> void:
	if is_persistent:
		_timer += delta
		if _timer >= tick_rate:
			_timer = 0.0
			_apply_damage()

func _apply_damage() -> void:
	var targets = get_overlapping_bodies()
	
	for body in targets:
		if body == caster: continue
		if not body is Unit or body.is_dead: continue
		
		# Filters
		if not can_hit_teammates and body.team == caster.team: continue
		if body.unit_type == Unit.UnitType.TOWER and not can_hit_structures: continue
			
		if !effects_to_apply.is_empty():
			# THE FIX: Provide BOTH keys so all effect types work
			# Inside _apply_damage()
			var context = { 
				"target": body, 
				"target_unit": body,
				"category": "spell", # Tell the engine it's a spell
				"is_aoe": true              # Tell the engine it's AoE
			}
			for effect in effects_to_apply:
				if effect:
					effect.on_execute(caster, skill_level, context, null)
