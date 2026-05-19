extends ItemEffect
class_name EffectStacking

# --- NEW: Enum for Filtering ---
enum TriggerCategory { ANY, ATTACK, SPELL ,ON_HIT}

@export_group("Stacking Config")
@export var status_id: String = "guinsoos_rage"
@export var max_stacks: int = 4
@export var stack_duration: float = 6.0

# --- NEW: The Filter Export ---
@export_group("Trigger Condition")
## Choose what type of damage grants stacks!
@export var trigger_category: TriggerCategory = TriggerCategory.ANY

@export_group("Mode Toggle")
@export var deal_damage_on_max: bool = false

@export_group("Bonuses Per Stack")
@export var stats_per_stack: Dictionary = {}

@export_group("Max Stack Bonuses")
@export var stats_at_max: Dictionary = {}

@export_group("Damage Ramping")
@export var dmg_increase_per_stack: float = 0.0 
@export var max_dmg_increase: float = 0.0    
  
var _is_processing: bool = false

func on_damage_dealt(owner: Unit, context: Dictionary) -> void:
	# 1. Basic Guards
	if context.get("category") == "proc": 
		return
		
	# 2. Filter Category Validation
	var damage_category = context.get("category", "")
	var applies_on_hit = context.get("allow_on_hits", false)
	
	match trigger_category:
		TriggerCategory.ATTACK:
			if damage_category != "attack": return
		TriggerCategory.SPELL:
			if damage_category != "spell": return
		TriggerCategory.ON_HIT:
			if not applies_on_hit: return    

	if _is_processing: return
	
	var target = context.get("target")
	if not is_instance_valid(target): return

	# Fetch or apply the status effect node branch
	var status = owner.status_container.get_node_or_null(status_id)
	
	# OPTIMIZATION: If we are already at max stacks AND this item deals damage on max,
	# trigger the Kraken proc immediately, reset, and skip status re-application calculations!
	if status and status.stacks >= max_stacks and deal_damage_on_max:
		status.stacks = 0 # Reset ONLY for Kraken-style items!
		_is_processing = true
		_trigger_kraken_damage(owner, target)
		_is_processing = false
		owner.recalculate_stats()
		return # Exit early!

	# Otherwise, standard building logic applies (e.g. Rageblade updates or building up to Kraken)
	owner.apply_status_effect(status_id, stack_duration, 1, 1.0, owner)
	status = owner.status_container.get_node_or_null(status_id)
	
	if status:
		status.max_stacks = max_stacks 
		status.stats_to_buff = stats_per_stack
		status.stats_at_max = stats_at_max
		status.damage_ramp_per_stack = dmg_increase_per_stack
		status.damage_ramp_cap = max_dmg_increase
		
		# Secondary Check: If we just hit max stacks on this hit and it is a Kraken item
		if status.stacks >= max_stacks and deal_damage_on_max:
			status.stacks = 0 
			_is_processing = true
			_trigger_kraken_damage(owner, target)
			_is_processing = false
			
		owner.recalculate_stats()

func _trigger_kraken_damage(owner: Unit, target: Node2D) -> void:
	if not is_instance_valid(target): return
	var level_factor = (owner.level - 1) / 17.0 
	var base_dmg = lerp(140.0, 310.0, level_factor)
	var hp_ratio = target.current_health / target.get_total(Unit.Stat.HP)
	var missing_hp_ratio = 1.0 - hp_ratio
	var multiplier = 1.0 + (missing_hp_ratio * 0.5)
	var final_damage = base_dmg * multiplier
	
	# NOTE: We pass "proc" as the category so item effects don't infinite-loop!
	owner.deal_damage(target, final_damage, "physical", "proc")
	tracker.proc_damage+=final_damage
