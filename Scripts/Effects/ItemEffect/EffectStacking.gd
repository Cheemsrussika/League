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
func on_damage_dealt(owner: Unit, context: Dictionary):
	# 1. Basic Guards
	if context.get("category") == "proc": return
	
	
	# 2. Filter Logic (Same as yours)
	var damage_category = context.get("category", "")
	var applies_on_hit = context.get("allow_on_hits", false)
	
	match trigger_category:
		TriggerCategory.ATTACK:
			if damage_category != "attack": return
		TriggerCategory.SPELL:
			if damage_category != "spell": return
		TriggerCategory.ON_HIT:
			if not applies_on_hit: return    
			
	# --- NEW: THE ANTI-LOOP LOCK ---
	# If we are currently processing damage, ignore any new damage triggers
	if _is_processing: return
	_is_processing = true # Lock the script!
	
	owner.apply_status_effect(status_id, stack_duration, 1, 1.0, owner)
	var status = owner.status_container.get_node_or_null(status_id)
	
	if status:
		status.max_stacks = max_stacks 
		status.stats_to_buff = stats_per_stack
		status.stats_at_max = stats_at_max
		status.damage_ramp_per_stack = dmg_increase_per_stack
		status.damage_ramp_cap = max_dmg_increase
		
		if status.stacks >= max_stacks:
			if deal_damage_on_max:
				# --- NEW: RESET STACKS FIRST! ---
				# You MUST reset stacks to 0 before dealing the damage
				status.stacks = 0 
				_trigger_kraken_damage(owner, context.get("target"))
			
		owner.recalculate_stats()

	# Unlock the script so it can listen for the next real attack
	_is_processing = false

func _trigger_kraken_damage(owner: Unit, target: Node2D):
	if not target: return
	var level_factor = (owner.level - 1) / 17.0 
	var base_dmg = lerp(140.0, 310.0, level_factor)
	var hp_ratio = target.current_health / target.get_total(Unit.Stat.HP)
	var missing_hp_ratio = 1.0 - hp_ratio
	var multiplier = 1.0 + (missing_hp_ratio * 0.5)
	var final_damage = base_dmg * multiplier
	owner.deal_damage(target, final_damage, "physical", "attack")
