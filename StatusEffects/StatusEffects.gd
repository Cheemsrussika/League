extends Node
class_name StatusEffect

# Generic Data
var id: String = ""
var duration: float = 0.0
var stacks: int = 1
var max_stacks: int = 6
var power: float = 0.0      # Generic value (Slow %, Damage Amp, etc)
var source: Node = null     # Who applied this?

# Flags
var type: String = "buff"   # "buff", "debuff", "dot", "cc", "flag"
var is_permanent: bool = false

# --- LIFECYCLE ---
func on_apply(unit):
	# Override for immediate effects
	pass

func refresh(new_duration, new_stacks_add, new_power):
	duration = new_duration
	stacks = clamp(stacks + new_stacks_add, 0, max_stacks)
	if new_power > power:
		power = new_power

func on_stat_calculation(unit):
	# Override to modify stats
	pass
func _ready():
	print("Status Node Created: ", name)

func _process(delta):
	if is_permanent: return
	if duration > 0:
		duration -= delta
		if duration <= 0:
			expire()

func expire():
	var status_container = get_parent()
	if status_container:
		var unit = status_container.get_parent()
		queue_free()
		if unit and unit.has_method("recalculate_stats"):
			unit.call_deferred("recalculate_stats")
			
