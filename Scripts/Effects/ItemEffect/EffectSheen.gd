# res://Scripts/Items/Passives/Effect_Sheen.gd
extends ItemEffect
class_name Effect_Sheen

@export_group("Sheen Logic")
@export var buff_id: String = "sheen_proc_active"
@export var sheen_cooldown: float = 1.5
@export var charge_duration: float = 10.0

@export_group("Damage Scaling")
@export var damage_scaling: Array[ScalingFactor] = [] 
@export var is_magic_damage: bool = false
@export var percent_hp_damage: float = 0.0 

@export_group("Restore Settings")
@export_enum("Health", "Resource", "Both") var mode: String = "Resource"
@export var restore_scaling: Array[ScalingFactor] = [] 
@export var restore_percent_target_hp: float = 0.0 

var last_proc_time: int = -999999

@export_group("Zone Settings")
@export var zone_scene: PackedScene
@export var zone_duration: float = 2.0
@export var zone_tick_rate: float = 0.25
@export var zone_effects: Array[SkillEffect] = []

@export_group("Zone Scaling")
@export var base_radius: float = 150.0
@export var radius_scaling: Array[ScalingFactor] = [] 

@export_group("Proc Buff Settings (On Cast)")
## The ID of the Status node to apply (e.g., "trinity_force_speed")
@export var proc_buff_id: String = ""
## A dictionary of stats to apply when the skill is cast. 
@export var proc_buff_stats: Dictionary = {}

var is_currently_proccing: bool = false

# --- 1. CHARGE LOGIC (Triggers on Skill Cast) ---
func on_ability_activated(user: Champion, context: Dictionary) -> void:
	if context.get("is_toggle", false): return
	
	var now = Time.get_ticks_msec()
	var cooldown_ms = int(sheen_cooldown * 1000.0)
	
	if now >= last_proc_time + cooldown_ms and not user.has_status(buff_id):
		# 1. Apply the Sheen charge for the next attack
		user.apply_status_effect(buff_id, charge_duration, 1, 0.0, user)
		
		# 2. IMMEDIATELY GIVE THE STATS BUFF (Tied to charge_duration)
		if proc_buff_id != "":
			user.apply_status_effect(proc_buff_id, charge_duration, 1, 0.0, user)
			
			if not proc_buff_stats.is_empty() and user.get("status_container") != null:
				var status_node = user.status_container.get_node_or_null(proc_buff_id)
				if status_node:
					if "stats_to_buff" in status_node:
						status_node.stats_to_buff = proc_buff_stats
					
					if user.has_method("recalculate_stats"):
						user.recalculate_stats()
		
		if user.inventory: user.inventory.request_ui_refresh()

# --- 2. ATTACK LOGIC ---
func on_attack(user: Unit, context: Dictionary) -> void:
	if is_currently_proccing: return
	if not user.has_status(buff_id): return
	
	var target = context.get("target")
	if not is_instance_valid(target): return
	
	is_currently_proccing = true
	_proc_sheen(user, target)
	
	last_proc_time = Time.get_ticks_msec()
	
	# --- CONSUME BOTH BUFFS ---
	var status = user.status_container.get_node_or_null(buff_id)
	if status: status.expire()
	
	if proc_buff_id != "":
		var proc_status = user.status_container.get_node_or_null(proc_buff_id)
		if proc_status: proc_status.expire()
	
	if user.inventory: user.inventory.request_ui_refresh()
	user.get_tree().process_frame.connect(func(): is_currently_proccing = false, CONNECT_ONE_SHOT)

# --- 3. INTERNAL MATH ---
func _proc_sheen(user: Champion, target: Node2D):
	# --- 1. DAMAGE CALCULATION ---
	var bonus_damage = 0.0
	var spawn_pos = target.global_position
	
	for factor in damage_scaling:
		bonus_damage += factor.calculate_value(user, target)
	
	if percent_hp_damage > 0 and target.has_method("get_max_health"):
		bonus_damage += target.get_max_health() * (percent_hp_damage / 100.0)

	var type = "magic" if is_magic_damage else "physical"
	var dealt = user.deal_damage(target, bonus_damage, type, "item_proc")

	# --- 2. ZONE LOGIC ---
	if zone_scene:
		var hitbox = zone_scene.instantiate()
		
		if hitbox.has_method("set"):
			hitbox.set("caster", user)
			hitbox.set("skill_level", user.level)
			hitbox.set("effects_to_apply", zone_effects)
			hitbox.set("is_persistent", true)
			hitbox.set("tick_rate", zone_tick_rate)
			hitbox.set("can_hit_teammates", false)
			hitbox.set("can_hit_structures", false)

		var final_radius = base_radius
		for factor in radius_scaling:
			final_radius += factor.calculate_value(user, target)
			
		hitbox.global_position = spawn_pos
		hitbox.scale = Vector2.ZERO 
		
		var tween = user.create_tween()
		tween.tween_property(hitbox, "scale", Vector2(final_radius, final_radius), 0.2)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)

		user.get_tree().current_scene.add_child.call_deferred(hitbox)
		
		user.get_tree().create_timer(zone_duration).timeout.connect(func():
			if is_instance_valid(hitbox):
				hitbox.set_deferred("monitoring", false)
				hitbox.queue_free()
		)

	# --- 3. RESTORE CALCULATION ---
	var total_restore = 0.0
	
	for factor in restore_scaling:
		total_restore += factor.calculate_value(user, target)
	
	if restore_percent_target_hp > 0 and target.has_method("get_max_health"):
		total_restore += target.get_max_health() * (restore_percent_target_hp / 100.0)

	var res_amt = 0.0
	var hp_amt = 0.0
	match mode:
		"Health": hp_amt = total_restore
		"Resource": res_amt = total_restore
		"Both": 
			hp_amt = total_restore
			res_amt = total_restore

	if hp_amt > 0 or res_amt > 0:
		user.restore(res_amt, hp_amt)
		if "tracker" in self: tracker["healing"] += hp_amt
	
	if "tracker" in self: 
		tracker["damage"] += dealt
		tracker["procs"] += 1
