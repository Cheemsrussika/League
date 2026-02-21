extends ItemEffect
class_name EffectYunTalWildarrows

@export_group("Bleed Settings")
@export var bleed_duration: float = 2.0
@export var tick_interval: float = 0.5 
@export var total_ad_ratio: float = 0.35 

var total_damage_dealt: float = 0.0

# This ID must exist in your StatusLibrary!
const BLEED_ID = "yuntal_bleed" 

func on_attack_landed(user: Unit, context: Dictionary) -> void:
	if not context.get("is_crit", false): return
	if not user.status_damage_dealt.is_connected(_on_status_damage_heard):
		user.status_damage_dealt.connect(_on_status_damage_heard)
	var target = context["target"]
	if not is_instance_valid(target): return

	# Calculate Damage: 35% of Total AD
	var total_bleed_damage = user.get_total(Unit.Stat.AD) * total_ad_ratio
	target.apply_status_effect(BLEED_ID, bleed_duration, 1, total_bleed_damage, user)
	var status = target.status_container.get_node_or_null(BLEED_ID)
	if status:
		if "damage_type" in status: status.damage_type = "physical"
		if "tick_interval" in status: status.tick_rate = tick_interval

func on_apply(user: Unit):
	if not user.status_damage_dealt.is_connected(_on_status_damage_heard):
		user.status_damage_dealt.connect(_on_status_damage_heard)

func _on_status_damage_heard(status_id: String, receipt: Dictionary):
	if status_id == BLEED_ID:
		total_damage_dealt += receipt["mitigated"]

func get_tooltip_extra() -> String:
	return "\nDealt [color=red]%.0f[/color] total bleed damage" % total_damage_dealt
