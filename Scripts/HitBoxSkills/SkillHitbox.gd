# res://Skills/Hitboxes/SkillHitbox.gd
extends Area2D

var caster: Node2D
var effects_to_apply: Array[SkillEffect] = []
var skill_level: int
var tick_rate: float = 0.5
var is_persistent: bool = false

# Injected Filters
var can_hit_teammates: bool = false
var can_hit_structures: bool = false # Bridges to Unit.UnitType.TOWER

var _timer: float = 0.0

func _ready() -> void:
	if not is_persistent:
		# Wait 2 frames to be absolutely safe for physics registration
		await get_tree().physics_frame
		await get_tree().physics_frame
		_scan_and_apply()

func _process(delta: float) -> void:
	if is_persistent:
		_timer += delta
		if _timer >= tick_rate:
			_timer = 0.0
			_scan_and_apply()

func _scan_and_apply():
	var targets = get_overlapping_bodies()
	for body in targets:
		# 1. Basic Checks
		if body == caster: continue
		if not body is Unit or body.is_dead: continue
		
		# 2. Team Filtering
		if not can_hit_teammates:
			if body.team == caster.team:
				continue
		
		# 3. Structure Filtering (Towers)
		# Accessing the UnitType enum from your Unit script
		if body.unit_type == Unit.UnitType.TOWER and not can_hit_structures:
			continue
			
		if !effects_to_apply.is_empty():
			# THE FIX: Provide BOTH keys so all effect types work
			# Inside _apply_damage()
			var context = { 
				"target": body, 
				"target_unit": body,
				"category": "spell", # Tell the engine it's a spell
				"is_aoe": false              # Tell the engine it's AoE
			}
			for effect in effects_to_apply:
				if effect:
					effect.on_execute(caster, skill_level, context, null)
