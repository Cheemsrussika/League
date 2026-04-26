extends ItemEffect
class_name EffectStatMod

@export_group("Stat Settings")
@export var stat_type: Champion.Stat      
@export var flat_amount: float = 0.0   

@export_group("Scaling Settings")
@export var scaling_factors: Array[ScalingFactor] = []

@export_group("Target Scaling Settings")
## Check this ONLY if this item scales off an enemy's stats!

## How long the stats last after you stop hitting them.
@export var combat_buff_duration: float = 3.0

@export_group("Resource Conversion")
@export var requires_mana: bool = false
@export var alternate_stat_type: Champion.Stat 
@export var alternate_flat_amount: float = 0.0

var active_target: Unit = null

func on_stat_calculation(user: Node2D) -> void:
	if not user is Champion: return
	
	var current_stat_to_give = stat_type
	var final_amount = flat_amount
	
	if requires_mana and user.resource_type != Champion.ResourceType.MANA:
		current_stat_to_give = alternate_stat_type
		final_amount = alternate_flat_amount
		if current_stat_to_give == null: 
			return

	if not Champion.STAT_MAP.has(current_stat_to_give): return
	var target_stat_string = Champion.STAT_MAP[current_stat_to_give]
	
	for factor in scaling_factors:
		final_amount += factor.calculate_value(user, active_target)

	if not is_zero_approx(final_amount):
		user.modify_stat(target_stat_string, final_amount)

func on_attack(user: Unit, context: Dictionary) -> void:
	# --- SMART PERFORMANCE CHECK ---
	# Automatically scan our ScalingFactors. 
	# If NONE of them are looking at the target, we abort to save performance!
	var needs_target = false
	for factor in scaling_factors:
		if factor.source == 1: 
			needs_target = true
			break
			
	if not needs_target: return 
	
	# --- PROCEED WITH STAT STEALING ---
	var target = context.get("target")
	
	if is_instance_valid(target) and target is Unit:
		active_target = target
		
		if user.has_method("recalculate_stats"):
			user.recalculate_stats()
			
		user.get_tree().create_timer(combat_buff_duration).timeout.connect(func():
			if active_target == target: 
				active_target = null
				if is_instance_valid(user) and user.has_method("recalculate_stats"):
					user.recalculate_stats()
		)
