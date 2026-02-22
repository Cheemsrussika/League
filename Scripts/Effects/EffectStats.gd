extends ItemEffect
class_name EffectStatMod

# --- ENUMS ---
enum ScalingMode { TOTAL, BASE, BONUS }

@export_group("Stat Settings")
@export var stat_type: Champion.Stat      
@export var flat_amount: float = 0.0   

@export_group("Scaling Settings")
@export var scaling_factor: float = 0.0   
@export var scaling_source: Champion.Stat 
@export var scaling_mode: ScalingMode = ScalingMode.TOTAL

@export_group("Resource Conversion")
@export var requires_mana: bool = false
@export var alternate_stat_type: Champion.Stat 
@export var alternate_flat_amount: float = 0.0

func on_stat_calculation(user: Node2D) -> void:
	if not user is Champion: return
	
	var current_stat_to_give = stat_type
	var final_amount = flat_amount
	
	if requires_mana and user.resource_type != Champion.ResourceType.MANA:
		current_stat_to_give = alternate_stat_type
		final_amount = alternate_flat_amount
		if current_stat_to_give == null: 
			return

	# 2. Safety check mapping
	if not Champion.STAT_MAP.has(current_stat_to_give): return
	var target_stat_string = Champion.STAT_MAP[current_stat_to_give]
	if scaling_factor != 0.0:
		if Champion.STAT_MAP.has(scaling_source):
			var source_key = Champion.STAT_MAP[scaling_source]
			var source_value = 0.0
			match scaling_mode:
				ScalingMode.TOTAL:
					source_value = user.get_total(scaling_source)
				ScalingMode.BASE:
					source_value = user.base_stats.get(source_key, 0.0)
				ScalingMode.BONUS:
					source_value = user.bonus_stats.get(source_key, 0.0)
			final_amount += source_value * scaling_factor
	print(final_amount)
	print(flat_amount)
	if not is_zero_approx(final_amount):
		user.modify_stat(target_stat_string, final_amount)
