extends Node2D
class_name TowerProjectile

@export var speed: float = 500.0
var target: Unit = null
var damage: float = 0.0
var attacker: Node = null
var active: bool = false

func launch(p_target: Unit, p_damage: float, p_attacker: Node, heat_level: int):
	target = p_target
	damage = p_damage
	attacker = p_attacker
	active = true
	var s = 1.0 + (heat_level * 0.3)
	scale = Vector2(s, s)

	modulate = Color(1, 1.0 - (heat_level * 0.2), 1.0 - (heat_level * 0.3))

func _process(delta: float):
	if not active or not is_instance_valid(target):
		if active: queue_free() # Target lost mid-air
		return
		
	var target_pos = target.global_position + Vector2(0, -20)
	var direction = global_position.direction_to(target_pos)
	global_position += direction * speed * delta
	
	rotation = direction.angle()
	if global_position.distance_to(target_pos) < 20.0:
		_on_impact()

func _on_impact():
	active = false
	if is_instance_valid(target):
		target.take_damage(damage, "magic", attacker, false, "attack")
		if is_instance_valid(attacker) and attacker.has_method("_trigger_passive_effects"):
			attacker._trigger_passive_effects("on_hit", {"target": target})
			var damage_context = {
				"target": target,
				"category": "spell", 
				"type": "magic"      
			}
			attacker._trigger_passive_effects("on_damage_dealt", damage_context)
	queue_free()
