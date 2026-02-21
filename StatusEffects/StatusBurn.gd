extends StatusEffect
class_name StatusBurn

var damage_per_tick: float = 0.0
var tick_rate: float = 0.5
var _timer: float = 0.0
var damage_type: String = "magic"
var caster: Unit

func _process(delta):
	super._process(delta) 
	if damage_per_tick <= 0: return 
	_timer += delta
	if _timer >= tick_rate:
		_timer = 0.0
		_execute_burn_tick()
func _execute_burn_tick():
	var victim = get_parent().get_parent() as Unit
	if is_instance_valid(victim) and not victim.is_dead:
		var receipt = victim.take_damage(damage_per_tick, damage_type, caster, false, "proc")
		if caster and caster.has_method("_on_status_dealt_damage"):
			caster._on_status_dealt_damage(id, receipt)
