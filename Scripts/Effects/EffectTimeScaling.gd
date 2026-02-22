extends ItemEffect
class_name EffectTimeScaling

@export_group("Scaling Config")
@export var interval_seconds: float = 60.0  # 1 Minute
@export var max_stacks: int = 10
@export var evolve_at_max: bool = true      # Trigger "Level Up" effect at max?

@export_group("Stats Per Stack")
@export var health_per_stack: float = 20.0
@export var mana_per_stack: float = 10.0
@export var ap_per_stack: float = 4.0

# Runtime Variables
var current_stacks: int = 0
var time_accumulator: float = 0.0
var _is_fully_stacked: bool = false

# Reset state when equipped
func on_equip(user: Champion) -> void:
	current_stacks = 0
	time_accumulator = 0.0
	_is_fully_stacked = false

# Count time every frame
func on_update(user: Unit, delta: float) -> void:
	if current_stacks >= max_stacks:
		return

	time_accumulator += delta
	
	# Check if a minute has passed
	if time_accumulator >= interval_seconds:
		time_accumulator -= interval_seconds
		_add_stack(user)

func _add_stack(user: Unit) -> void:
	current_stacks += 1
	user.recalculate_stats()
	if current_stacks >= max_stacks and not _is_fully_stacked:
		_is_fully_stacked = true
		if evolve_at_max:
			pass#TODO:add one level at max stack

func on_stat_calculation(user: Unit) -> void:
	if current_stacks <= 0: return

	# Calculate totals
	var bonus_hp = health_per_stack * current_stacks
	var bonus_mana = mana_per_stack * current_stacks
	var bonus_ap = ap_per_stack * current_stacks
	user.modify_stat("health", bonus_hp)
	user.modify_stat("Mana", bonus_mana)    
	user.modify_stat("ability_power", bonus_ap)

func get_tooltip_extra() -> String:
	return "Stacks: %d / %d" % [current_stacks, max_stacks]
	
