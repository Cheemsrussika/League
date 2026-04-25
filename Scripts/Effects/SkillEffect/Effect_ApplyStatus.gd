# res://Skills/Effects/Effect_ApplyStatus.gd
extends SkillEffect
class_name Effect_ApplyStatus

@export_group("Status Info")
@export var status_id: String = "" # e.g., "darius_bleed" or "slow"
@export var duration: float = 3.0
@export var max_stacks: int = 5

@export_group("Scaling")
## Which stat makes the status stronger? (e.g., AD for Bleed, AP for Slow)
@export var scaling_stat: Unit.Stat = Unit.Stat.AD
@export var scaling_ratio: float = 0.1

func on_execute(caster: Node2D, level: int, target_data: Dictionary, _ref: Resource):
	var target = target_data.get("target_unit")
	if not is_instance_valid(target) or not target.has_method("apply_status_effect"):
		return
	
	# Calculate power based on caster stats
	var power = caster.get_total(scaling_stat) * scaling_ratio
	
	# Apply it to the target
	target.apply_status_effect(status_id, duration, max_stacks, power, caster)
	print("Applied status: ", status_id, " to ", target.name)
