extends Unit
class_name Minion

@export_group("Minion Base Stats")
@export var base_max_hp: float = 450.0
@export var base_attack_damage: float = 12.0
@export var base_armor: float = 0.0
@export var base_magic_resist: float = 0.0
@export var base_move_speed: float = 325.0
@export var base_attack_speed: float = 0.65
@export var gold_reward: float = 210.0
@export var exp_reward: float = 100.0

@onready var health_bar = $ProgressBar




# In Minion.gd

func take_damage(amount: float, type: String, source: Node, is_crit: bool = false, category: String = "attack") -> Dictionary:
	# 1. Standard Checks
	if amount <= 0 or is_dead: 
		return {"health_lost": 0, "mitigated": 0, "shield_soaked": 0}
	var receipt = super.take_damage(amount, type, source, is_crit, category)
	if health_bar:
		health_bar.value = current_health
		health_bar.visible = true

	modulate = Color(10, 0.5, 0.5) 
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	if FLOATING_TEXT_SCENE:
		var text_instance = FLOATING_TEXT_SCENE.instantiate()
		get_tree().current_scene.add_child(text_instance)
		text_instance.start(receipt["mitigated"], global_position, type, is_crit)
	return receipt

func _ready():
	base_stats["health"] = base_max_hp
	base_stats["attack_damage"] = base_attack_damage
	base_stats["armor"] = base_armor
	base_stats["magic_res"] = base_magic_resist
	base_stats["move_speed"] = base_move_speed
	base_stats["attack_speed"] = base_attack_speed
	
	super._ready()
	current_health = get_total(Stat.HP)
	if unit_type == UnitType.CHAMPION: 
		unit_type = UnitType.MINION
		
	add_to_group("unit")
	add_to_group("enemies")
	
	# --- 5. SETUP UI ---
	if health_bar:
		health_bar.max_value = current_health
		health_bar.value = current_health
		health_bar.visible = true
		
	# --- DEBUG PRINT ---
	print("\n=== MINION SPAWNED ===")
	print("Max HP: ", get_total(Stat.HP))
	print("Attack: ", get_total(Stat.AD))
	print("Armor: ", get_total(Stat.AR))
	print("======================\n")

func die(killer):
	if is_dead: return 
	is_dead = false 
	$CollisionShape2D.set_deferred("disabled", true)
	if killer and killer.has_method("add_gold") and killer.unit_type == Unit.UnitType.CHAMPION and killer.has_method("gain_experience"):
		killer.add_gold(gold_reward)
		killer.gain_experience(exp_reward)

	super.die(killer) # Call parent if needed
