# res://Scripts/Items/Passives/Effect_Sheen.gd
extends ItemEffect
class_name Effect_Sheen

@export_group("Sheen Logic")
## The unique ID for the buff. Used to check if the next attack should proc.
@export var buff_id: String = "sheen_proc_active"
@export var sheen_cooldown: float = 1.5
@export var charge_duration: float = 10.0

@export_group("Damage Scaling")
## Multiple stats allowed (e.g., AD + AP for Lich Bane)
@export var scaling_stats: Array[Unit.Stat] = [Unit.Stat.AD]
@export var scaling_ratios: Array[float] = [1.0]
@export var is_magic_damage: bool = false
@export var percent_hp_damage: float = 0.0 

@export_group("Restore Settings")
@export_enum("Health", "Resource", "Both") var mode: String = "Resource"
@export var restore_stats: Array[Unit.Stat] = [Unit.Stat.AD]
@export var restore_ratios: Array[float] = [0.4]
@export var restore_percent_target_hp: float = 0.0 

# Use int for millisecond math to avoid floating point errors
var last_proc_time: int = -999999

@export_group("Zone Settings")
@export var zone_scene: PackedScene
@export var zone_duration: float = 2.0
@export var zone_tick_rate: float = 0.25
## What the zone actually does (Slow, Damage, Poison, etc.)
@export var zone_effects: Array[SkillEffect] = []

@export_group("Zone Scaling")
@export var base_radius: float = 150.0
## Allows radius to scale with anything (Armor, HP, etc.)
@export var radius_scaling_stats: Array[Unit.Stat] = [Unit.Stat.AR]
@export var radius_scaling_ratios: Array[float] = [0.5]

var is_currently_proccing: bool = false

# --- 1. CHARGE LOGIC ---
# This matches the hook name in your Champion.gd _trigger_passive_effects call
func on_ability_activated(user: Champion, context: Dictionary) -> void:
	# Ignore toggle abilities if necessary
	if context.get("is_toggle", false): return
	
	var now = Time.get_ticks_msec()
	var cooldown_ms = int(sheen_cooldown * 1000.0)
	
	# Only charge if off cooldown AND not already charged
	if now >= last_proc_time + cooldown_ms and not user.has_status(buff_id):
		user.apply_status_effect(buff_id, charge_duration, 1, 0.0, user)
		
		# Optional: Refresh UI to show the sheen glow on the item
		if user.inventory: user.inventory.request_ui_refresh()

# --- 2. ATTACK LOGIC ---
func on_attack(user: Unit, context: Dictionary) -> void:
	# Check if the champion actually has the buff
	if is_currently_proccing: return
	if not user.has_status(buff_id): return
	
	var target = context.get("target")
	if not is_instance_valid(target): return
	is_currently_proccing = true
	# Execute the logic
	_proc_sheen(user, target)
	
	# Update cooldown timer
	last_proc_time = Time.get_ticks_msec()
	
	# Remove the buff status (it was consumed)
	var status = user.status_container.get_node_or_null(buff_id)
	if status: status.expire()
	
	# Optional: Refresh UI
	if user.inventory: user.inventory.request_ui_refresh()
	user.get_tree().process_frame.connect(func(): is_currently_proccing = false, CONNECT_ONE_SHOT)

# --- 3. INTERNAL MATH ---
func _proc_sheen(user: Champion, target: Node2D):
	# 1. Damage Calculation
	var bonus_damage = 0.0
	var spawn_pos = target.global_position
	for i in range(scaling_stats.size()):
		var stat = scaling_stats[i]
		var ratio = scaling_ratios[i]
		bonus_damage += user.get_total(stat) * ratio
	
	if percent_hp_damage > 0 and target.has_method("get_max_health"):
		bonus_damage += target.get_max_health() * (percent_hp_damage / 100.0)

	var type = "magic" if is_magic_damage else "physical"
	var dealt = user.deal_damage(target, bonus_damage, type, "item_proc")
	# ... previous damage logic ...

	if zone_scene:
		var hitbox = zone_scene.instantiate()
		
		# 1. Apply Logic (Matching your Effect_SpawnHitbox reference)
		if hitbox.has_method("set"):
			hitbox.set("caster", user)
			hitbox.set("skill_level", user.level)
			hitbox.set("effects_to_apply", zone_effects)
			hitbox.set("is_persistent", true)
			hitbox.set("tick_rate", zone_tick_rate)
			
			# Pass Filters
			hitbox.set("can_hit_teammates", false)
			hitbox.set("can_hit_structures", false)

		# 2. Calculate dynamic radius
		var final_radius = base_radius
		for i in range(radius_scaling_stats.size()):
			final_radius += user.get_total(radius_scaling_stats[i]) * radius_scaling_ratios[i]
			
		# 3. Apply Transform (Bloom animation)
		hitbox.global_position = spawn_pos
		hitbox.scale = Vector2.ZERO 
		
		var tween = user.create_tween()
		tween.tween_property(hitbox, "scale", Vector2(final_radius, final_radius), 0.2)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)

		# 4. Add to scene (Using the current_scene approach from your reference)
		user.get_tree().current_scene.add_child.call_deferred(hitbox)
		
		# 5. Handle Lifetime
		user.get_tree().create_timer(zone_duration).timeout.connect(func():
			if is_instance_valid(hitbox):
				hitbox.set_deferred("monitoring", false)
				hitbox.queue_free()
		)

	# 2. Restore Calculation
	var total_restore = 0.0
	for i in range(restore_stats.size()):
		total_restore += user.get_total(restore_stats[i]) * restore_ratios[i]
	
	if restore_percent_target_hp > 0 and target.has_method("get_max_health"):
		total_restore += target.get_max_health() * (restore_percent_target_hp / 100.0)

	# 3. Apply via Unified Restore
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
		tracker["healing"] += hp_amt
	
	# Update Tooltip Tracker
	tracker["damage"] += dealt
	tracker["procs"] += 1
