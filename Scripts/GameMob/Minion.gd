extends Unit
class_name Minion

@export_group("Minion Combat")
@export var is_ranged: bool = false
@export var projectile_scene: PackedScene 
@export var attack_cooldown: float = 1.5
@export var exp_value: float = 20.0 
@export var gold_drop: float = 20.0 
enum MinionRole { MELEE, RANGED, SIEGE, SUPER }
@export var minion_role: MinionRole = MinionRole.MELEE
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var ai = $MinionsAi 

var attack_timer: float = 0.0

func _ready():
	super._ready() # Sets unit_type, tags, etc.
	
	# 1. Find the component if it exists
	inventory = $InventoryComponent if has_node("InventoryComponent") else null
	if inventory:
		recalculate_stats()
	
	# 3. Initialize health AFTER stats are calculated (in case items gave bonus HP)
	current_health = get_total(Stat.HP)

	if progress_bar:
		progress_bar.max_value = current_health
		progress_bar.value = current_health
func set_lane_path(path: Path2D):
	if ai and ai.has_method("set_lane_path"):
		ai.set_lane_path(path)

func take_damage(amount: float, type: String, source: Node, is_crit: bool = false, category: String = "attack") -> Dictionary:
	if amount <= 0 or is_dead: 
		return {"health_lost": 0, "mitigated": 0, "shield_soaked": 0}
		
	var receipt = super.take_damage(amount, type, source, is_crit, category)
	
	if progress_bar:
		progress_bar.value = current_health
		progress_bar.visible = true

	# Flash effect
	modulate = Color(10, 0.5, 0.5) 
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	
	# Floating combat text
	if FLOATING_TEXT_SCENE:
		var text_instance = FLOATING_TEXT_SCENE.instantiate()
		get_tree().current_scene.add_child(text_instance)
		text_instance.start(receipt["mitigated"], global_position, type, is_crit)
		
	return receipt

func _physics_process(delta):
	if attack_timer > 0:
		attack_timer -= delta
		
	if ai.current_state == ai.State.ATTACKING and is_instance_valid(current_target):
		_try_attack()

func _try_attack():
	if attack_timer > 0 or not is_instance_valid(current_target) or current_target.is_dead:
		return
		
	attack_timer = attack_cooldown
	_trigger_passive_effects("on_attack", {"target": current_target})
	
	var damage = get_total(Unit.Stat.AD)
	
	if is_ranged and projectile_scene:
		var proj = projectile_scene.instantiate()
		get_tree().current_scene.add_child(proj)
		proj.global_position = global_position
		if proj.has_method("setup"):
			proj.setup(self, current_target, damage) 
	else:
		if current_target.has_method("take_damage"):
			current_target.take_damage(damage, "physical", self, false, "attack")
			var context = {"target": current_target, "category": "attack", "type": "physical"}
			_trigger_passive_effects("on_damage_dealt", context)

# For MINION:
func die(killer: Unit = null):
	if is_dead: return
	# Don't set is_dead here if super.die() does it!
	
	if is_instance_valid(killer) and killer.unit_type == UnitType.CHAMPION:
		if killer.has_method("gain_experience"): killer.gain_experience(exp_value) 
		if killer.has_method("add_gold"): killer.add_gold(gold_drop)
		killer.on_kill_trigger(self)
			
	super.die(killer) # Let the Unit class handle the actual deletion/signals
	queue_free() # Only keep this here if Unit.gd doesn't already delete it.
