extends ItemEffect
class_name EffectStacking

@export_group("Stacking Config")
@export var status_id: String = "guinsoos_rage"
@export var max_stacks: int = 4
@export var stack_duration: float = 6.0

@export_group("Mode Toggle")
@export var trigger_phantom_on_max: bool = true 
@export var hits_to_trigger_phantom: int = 3
var current_phantom_count: int = 0
@export var deal_damage_on_max: bool = false


@export_group("Bonuses Per Stack")
@export var stats_per_stack: Dictionary = {}

@export_group("Max Stack Bonuses")
@export var stats_at_max: Dictionary = {}

@export_group("Damage Ramping")
@export var dmg_increase_per_stack: float = 0.0 
@export var max_dmg_increase: float = 0.0      



func on_damage_dealt(owner: Unit, context: Dictionary):
	if context.get("category") == "proc": return
	if context.get("is_phantom"): return 
	owner.apply_status_effect(status_id, stack_duration, 1, 1.0, owner)
	var status = owner.status_container.get_node_or_null(status_id)
	
	if status:
		status.max_stacks = max_stacks 
		status.stats_to_buff = stats_per_stack
		status.stats_at_max = stats_at_max
		status.damage_ramp_per_stack = dmg_increase_per_stack
		status.damage_ramp_cap = max_dmg_increase
		if status.stacks >= max_stacks:
			if trigger_phantom_on_max:
				handle_phantom_logic(owner, context)
			if deal_damage_on_max:
				_trigger_kraken_damage(owner, context.get("target"))
				status.stacks = 0
		else:
			current_phantom_count = 0 
			
		owner.recalculate_stats()

func handle_phantom_logic(owner: Unit, context: Dictionary):
	current_phantom_count += 1
	if current_phantom_count >= hits_to_trigger_phantom:
		current_phantom_count = 0
		trigger_phantom_hit(owner, context)

func trigger_phantom_hit(owner: Unit, original_context: Dictionary):
	var phantom_context = original_context.duplicate()
	phantom_context["is_phantom"] = true
	phantom_context["category"] = "proc" 
	if owner.inventory and "items" in owner.inventory:
		for item in owner.inventory.items:
			if item and item.effects:
				for effect in item.effects:
					if effect == self: continue 
					if effect.has_method("on_attack"):
						effect.on_attack(owner, phantom_context)
func _trigger_kraken_damage(owner: Unit, target: Node2D):
	if not target: return
	var level_factor = (owner.level - 1) / 17.0 
	var base_dmg = lerp(140.0, 310.0, level_factor)
	var hp_ratio = target.current_health / target.get_total(Unit.Stat.HP)
	var missing_hp_ratio = 1.0 - hp_ratio
	var multiplier = 1.0 + (missing_hp_ratio * 0.5)
	var final_damage = base_dmg * multiplier
	owner.deal_damage(target, final_damage, "physical", "proc")
