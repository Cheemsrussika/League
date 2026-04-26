extends ItemEffect
class_name EffectOnHitAdvanced

# --- ENUMS ---
enum DamageType { PHYSICAL, MAGIC, TRUE }

# --- EXPORTS ---
@export_group("On Hit Damage")
@export var damage_type: DamageType = DamageType.PHYSICAL
@export var base_damage_on_hit: float = 15.0

@export_group("Slayer Logic (Target Multipliers)")
## Multiplier for specific unit types (e.g., 1.5 = 50% more damage to Minions)
@export var vs_minion_mult: float = 1.0
@export var vs_monster_mult: float = 1.0
@export var vs_champion_mult: float = 1.0
@export var vs_structure_mult: float = 1.0

@export_group("Advanced Scaling (LEGOs)")
## Use your ScalingFactor array for dynamic damage (AP, HP, Level, etc.)
@export var damage_scalings: Array[ScalingFactor] = []

@export_group("Percent HP Damage")
@export var damage_percent_melee: float = 0.0  
@export var damage_percent_ranged: float = 0.0  
@export var cap_vs_monsters: float = 60.0  

@export_group("Crit & Targeting")
@export var can_this_item_crit: bool = false 
@export var champions_only: bool = false 
@export var affects_structures: bool = true

@export_group("On Hit Stat Buff")
@export var BUFF_ID:String = "stat_buff" # Ensure this exists in your StatusLibrary!
@export var allow_buff: bool = false
## The stat the buff provides (e.g., Attack Speed)
@export var buff_stat: Unit.Stat = Unit.Stat.AS
@export var buff_amount: float = 0.30     
@export var buff_duration: float = 6.0    
@export var buff_cooldown: float = 12.0   
@export var cdr_on_hit: float = 1.0       
@export var cdr_on_crit: float = 1.5      

# --- INTERNAL TRACKING ---
var cooldown_ready_time: int = 0 
var last_added_raw: float = 0.0
var total_damage_added: float = 0.0


func on_attack_hit_post_mitigation(user: Unit, context: Dictionary) -> void:
	_execute_on_hit_logic(user, context)

func _execute_on_hit_logic(user: Unit, context: Dictionary) -> void:
	var target = context.get("target")
	if not is_instance_valid(target): return
	
	if context.get("allow_on_hits", true) == false: return
	if champions_only and target.unit_type != Unit.UnitType.CHAMPION: return
	
	var is_structure = (target.unit_type == Unit.UnitType.TOWER)
	if is_structure and not affects_structures: return

	var current_time = Time.get_ticks_msec()
	var effectiveness = context.get("on_hit_mult", 1.0)
	var is_crit = context.get("is_crit", false)

	# --- 1. BUFF LOGIC ---
	if allow_buff and effectiveness > 0:
		if not user.has_status(BUFF_ID):
			if current_time >= cooldown_ready_time:
				_activate_buff(user)
			else:
				var reduction = cdr_on_crit if is_crit else cdr_on_hit
				cooldown_ready_time -= int(reduction * 1000)

	# --- 2. DAMAGE CALCULATION ---
	var calculated_damage = base_damage_on_hit
	
	# Apply LEGO Scalings
	for factor in damage_scalings:
		if factor:
			calculated_damage += factor.calculate_value(user, target)

	# % HP Logic
	var percent_to_use = damage_percent_ranged if user.is_ranged() else damage_percent_melee
	if percent_to_use > 0:
		var percent_dmg = target.current_health * percent_to_use
		# Cap vs non-champions
		if target.unit_type in [Unit.UnitType.MINION, Unit.UnitType.MONSTER]:
			percent_dmg = min(percent_dmg, cap_vs_monsters)
		elif is_structure:
			percent_dmg = 0.0
		calculated_damage += percent_dmg

	# --- 3. TARGET TYPE MULTIPLIERS ---
	match target.unit_type:
		Unit.UnitType.MINION:   calculated_damage *= vs_minion_mult
		Unit.UnitType.MONSTER:  calculated_damage *= vs_monster_mult
		Unit.UnitType.CHAMPION: calculated_damage *= vs_champion_mult
		Unit.UnitType.TOWER:    calculated_damage *= vs_structure_mult

	# Final Adjustments
	calculated_damage *= effectiveness
	if can_this_item_crit and is_crit:
		calculated_damage *= user.get_total(Unit.Stat.CRIT_DMG)

	# --- 4. APPLY DAMAGE ---
	# --- 4. APPLY DAMAGE ---
	if calculated_damage > 0:
		var type_str = "physical"
		if damage_type == DamageType.MAGIC: type_str = "magic"
		elif damage_type == DamageType.TRUE: type_str = "true"

		# Pass a custom skill_context that explicitly allows Life Steal!
		var proc_context = { "allow_lifesteal": true }
		
		# We deal the damage directly, and it will trigger its own lifesteal!
		total_damage_added += user.deal_damage(target, calculated_damage, type_str, "proc", is_crit, proc_context)
		last_added_raw = calculated_damage 

	_update_item_ui(user)

func _activate_buff(user: Unit):
	# 1. Spawn the status node
	user.add_status(BUFF_ID, buff_duration, 1, 1, 0.0)
	var status_node = user.status_container.get_node_or_null(BUFF_ID)
	
	if status_node:
		if typeof(status_node.stats_to_buff) == TYPE_DICTIONARY:
			status_node.stats_to_buff.clear()
		
		var stat_key = Unit.STAT_MAP.get(buff_stat, "")
		if stat_key != "":
			status_node.stats_to_buff[stat_key] = buff_amount
	
	cooldown_ready_time = Time.get_ticks_msec() + int(buff_cooldown * 1000)
	user.recalculate_stats()

func _update_item_ui(user):
	if user.inventory: user.inventory.request_ui_refresh()

func get_tooltip_extra() -> String:
	var text = "Total Damage: %d\n" % int(total_damage_added)
	if allow_buff:
		var current_time = Time.get_ticks_msec()
		if current_time < cooldown_ready_time:
			var cd = (cooldown_ready_time - current_time) / 1000.0
			text += "[color=red]Buff CD: %.1fs[/color]" % cd
		else:
			text += "[color=cyan]Buff Ready[/color]"
	return text
