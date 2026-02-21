extends ItemEffect
class_name EffectOnHitAdvanced

# --- ENUMS ---
enum DamageType { PHYSICAL, MAGIC, TRUE }
enum ScalingMode { TOTAL, BASE, BONUS }

# --- EXPORTS ---
@export_group("On Hit Damage")
@export var damage_type: DamageType = DamageType.PHYSICAL
@export var damage_on_hit: float = 15.0

@export_group("Scaling")
@export var scaling_factor: float = 0.0   
@export var scaling_source: Champion.Stat = Champion.Stat.AP 
@export var scaling_mode: ScalingMode = ScalingMode.TOTAL

@export_group("Crit Behavior")
@export var can_this_item_crit: bool = false 

@export_group("Targeting")
@export var champions_only: bool = false 
@export var affects_structures: bool = false

@export_group("Percent HP Damage")
@export var damage_percent_melee: float = 0.0 
@export var damage_percent_ranged: float = 0.0 
@export var cap_vs_monsters: float = 60.0 

# --- BUFF EXPORTS ---
@export_group("On Hit Stat Buff")
@export var allow_buff: bool = false
@export var buff_stat: Champion.Stat = Champion.Stat.AS
@export var buff_amount: float = 0.30     
@export var buff_duration: float = 6.0    
@export var buff_cooldown: float = 12.0   
@export var cdr_on_hit: float = 1.0       
@export var cdr_on_crit: float = 1.5      

# --- INTERNAL TRACKING ---
var cooldown_ready_time: int = 0 
var last_added_raw: float = 0.0
var total_damage_added: float = 0.0
const BUFF_ID = "stat_buff"

# --- 1. STAT MODIFICATION ---


# --- 2. MAIN ATTACK LOGIC ---
func on_attack(user: Champion, context: Dictionary) -> void:
	var target = context.get("target")
	if not target or not is_instance_valid(target): return
	if not _try_start_cooldown(): return 
	if champions_only and target.unit_type != Unit.UnitType.CHAMPION: return
	
	var is_crit = context.get("is_crit", false)
	var current_time = Time.get_ticks_msec()

	# --- A. HANDLE BUFF & COOLDOWN ---
	if allow_buff:
		var has_buff = user.has_status(BUFF_ID)
		
		if not has_buff:
			if current_time >= cooldown_ready_time:
				_activate_buff(user)
			else:
				var reduction = cdr_on_crit if is_crit else cdr_on_hit
				cooldown_ready_time -= int(reduction * 1000)
				_update_item_ui(user)

	# --- B. HANDLE DAMAGE CALCULATION ---
	var calculated_damage = damage_on_hit
	var is_structure = (target.get("unit_type") == Unit.UnitType.TOWER)
	
	if is_structure and not affects_structures:
		return

	# Scaling
	if scaling_factor != 0.0:
		var source_value = 0.0
		var stat_key = Champion.STAT_MAP.get(scaling_source, "")
		if stat_key != "":
			match scaling_mode:
				ScalingMode.TOTAL: source_value = user.get_total(scaling_source)
				ScalingMode.BASE:  source_value = user.base_stats.get(stat_key, 0.0)
				ScalingMode.BONUS: source_value = user.bonus_stats.get(stat_key, 0.0)
		calculated_damage += source_value * scaling_factor

	# Percent HP
	var percent_to_use = 0.0
	if damage_percent_melee > 0 or damage_percent_ranged > 0:
		percent_to_use = damage_percent_ranged if user.is_ranged() else damage_percent_melee
	
	if percent_to_use > 0:
		var percent_dmg = target.current_health * percent_to_use
		if cap_vs_monsters > 0 and (target.unit_type == Unit.UnitType.MINION or target.unit_type == Unit.UnitType.MONSTER):
			percent_dmg = min(percent_dmg, cap_vs_monsters)
		elif target.unit_type == Unit.UnitType.TOWER:
			percent_dmg = 0.0
		calculated_damage += percent_dmg

	if can_this_item_crit and is_crit:
		calculated_damage *= user.get_total(Unit.Stat.CRIT_DMG)
	if calculated_damage > 0:
		if damage_type == DamageType.PHYSICAL:
			context.buckets["physical"] += calculated_damage
			last_added_raw = calculated_damage 
		else:
			var type_str = "magic" if damage_type == DamageType.MAGIC else "true"
			var dealt = user.deal_damage(target, calculated_damage, type_str, "proc", is_crit)
			total_damage_added += dealt
			last_added_raw = 0.0 
		
	_update_item_ui(user)

func _activate_buff(user: Champion):
	if !allow_buff: return
	user.add_status(BUFF_ID, buff_duration, 1, 1, 0.0, "flag")
	var status_node = user.status_container.get_node_or_null(BUFF_ID)
	if status_node:
		var stat_key = Champion.STAT_MAP.get(buff_stat, "")
		if stat_key != "":
			status_node.stats_to_buff = { stat_key: buff_amount }
	cooldown_ready_time = Time.get_ticks_msec() + int(buff_cooldown * 1000)
	user.recalculate_stats()
	_update_item_ui(user)

func _update_item_ui(user):
	if user.inventory: user.inventory.request_ui_refresh()

func on_bucket_damage_landed(user: Champion, report: Dictionary):

	if damage_type != DamageType.PHYSICAL: return 
	
	if report["type"] == "physical" and last_added_raw > 0:
		var post_mitigation_contribution = last_added_raw * report.get("ratio", 1.0)
		total_damage_added += post_mitigation_contribution
		last_added_raw = 0.0 
		_update_item_ui(user)

func get_tooltip_extra() -> String:
	var text = ""
	if total_damage_added > 0:
		text += "Damage: %d\n" % int(total_damage_added)
	if allow_buff:
		var current_time = Time.get_ticks_msec()
		var cd_left = (cooldown_ready_time - current_time) / 1000.0
		var active_time_assumed = cd_left - (buff_cooldown - buff_duration)
		
		if active_time_assumed > 0:
			text += "[color=green]BUFF DURATION LEFT: %.1f[/color]"%active_time_assumed
		elif cd_left > 0:
			text += "[color=red]CD: %.1fs[/color]" % cd_left
		else:
			text += "[color=cyan]Buff Ready[/color]"
			
	return text
