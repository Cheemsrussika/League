extends ItemEffect
class_name ItemEffect_ApplyDynamicBuff


@export_group("Trigger Filters")
@export_enum("any", "physical", "magic", "true") var required_damage_type: String = "any"
@export_enum("any", "attack", "spell", "on_hit") var required_category: String = "any"

@export_group("Status Definition")
@export var status_id: String = "custom_debuff" # e.g., "black_cleaver_shred", "trinity_speed"
@export var duration: float = 6.0
@export var stacks_per_hit: int = 1
@export var max_stacks: int = 1

@export_group("Stat Modifications")
@export var stat_to_modify: Unit.Stat = Unit.Stat.AR
@export var is_buff: bool = false # false = debuff (negative), true = buff (positive)
@export var value_per_stack: float = 0.05
@export_enum("percent", "flat") var modification_type: String = "percent"

func on_damage_dealt(user: Unit, context: Dictionary):
	var target = context.get("target")
	if not is_instance_valid(target) or target.unit_type == Unit.UnitType.TOWER: return

	# Filter checks...
	var dmg_type = context.get("damage_type", "physical")
	if required_damage_type != "any" and dmg_type != required_damage_type: return

	# Decide WHO gets the buff/debuff. (Trinity = User gets buff. Cleaver = Target gets debuff).
	var unit_to_affect = user if is_buff else target

	if unit_to_affect.has_method("apply_status_effect"):
		# Apply the base status container
		unit_to_affect.apply_status_effect(status_id, duration, stacks_per_hit, value_per_stack, user)
		
		# Inject the dynamic stat data into the created status!
		if unit_to_affect.status_container:
			var status = unit_to_affect.status_container.get_node_or_null(status_id)
			if status:
				status.max_stacks_allowed = max_stacks
				
				# Tell the status exactly what to do with the stats
				var actual_value = value_per_stack if is_buff else -value_per_stack
				
				if modification_type == "flat":
					status.stats_to_buff = { stat_to_modify: actual_value } # e.g., +20 Move Speed
				else:
					status.percent_stats_to_buff = { stat_to_modify: actual_value } # e.g., -5% Armor
				unit_to_affect.recalculate_stats()
