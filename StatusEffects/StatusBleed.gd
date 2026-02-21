extends StatusEffect 

var tick_timer: float = 0.0
var tick_rate: float = 0.5
var duration_at_start: float = 0.0

func _ready():
	duration_at_start = duration
	tick_timer = tick_rate

func _process(delta):
	duration -= delta
	tick_timer -= delta
	
	if tick_timer <= 0:
		apply_damage()
		tick_timer = tick_rate
		
	if duration <= 0:
		queue_free()

func apply_damage():
	var total_ticks = max(1.0, duration_at_start / tick_rate)
	var damage_per_tick = power / total_ticks
	var parent_unit = get_parent()
	while parent_unit and not parent_unit is Unit:
		parent_unit = parent_unit.get_parent()
	if parent_unit:
		var victim = get_parent().get_parent() # The one taking damage
		if victim and victim.has_method("take_damage"):
			var receipt = victim.take_damage(damage_per_tick, "physical", source, false, "status")
			if source and source.has_method("record_status_damage"):
				source.record_status_damage("yuntal_bleed", receipt)
