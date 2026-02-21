extends Control

@export var champion: Champion

# Child References - Case-sensitive check!
@onready var health_bar = get_node_or_null("HealthBar")
@onready var shield_bar = get_node_or_null("ShieldBar")
@onready var health_fill = get_node_or_null("HealthFill")
@onready var divider_rect = get_node_or_null("ColorRect")
@onready var resource_bar = get_node_or_null("Resourcebar") # Updated to match your screenshot name
@onready var level_label: Label = $LevelBox/LevelLabel
var max_hp 

func _ready() -> void:
	if not champion and get_parent() is Champion:
		champion = get_parent()
	# Debug print to verify
	if is_instance_valid(champion):
		print("Champion linked successfully: ", champion.name)
		champion.level_updated.connect(_on_level_updated)
		
		# 3. Set the initial level immediately
		_on_level_updated(champion.level)
	else:
		print("Warning: UI could not find Champion parent!")
	max_hp = champion.get_total(Champion.Stat.HP)
	champion.stats_recalculated.connect(update_shader_stats)
	if divider_rect and divider_rect.material:
		divider_rect.material.set_shader_parameter("max_health", max_hp)
func _on_level_updated(new_level: int):
	if level_label:
		level_label.text = str(new_level)
func update_shader_stats(unit: Unit):
	if not is_instance_valid(divider_rect): return
	var mat = divider_rect.material as ShaderMaterial 
	if mat:
		mat.set_shader_parameter("max_health", unit.get_total(Unit.Stat.HP))
func _process(_delta):
	if not is_instance_valid(champion): 
		return
	max_hp = champion.get_total(Champion.Stat.HP)
	var current_hp = champion.current_health
	var shield = champion.total_shield_amount
		
	var display_max = max(max_hp, current_hp + shield)

	if health_bar:
		health_bar.max_value = display_max
		health_bar.value = display_max # The gray background
		
	if shield_bar:
		shield_bar.max_value = display_max
		shield_bar.value = current_hp + shield
		
	if health_fill:
		health_fill.max_value = display_max
		health_fill.value = current_hp

	_update_resource_logic()
	_update_colors()

func _update_resource_logic():
	if not resource_bar: return
	
	var max_res = 0.0
	if champion.use_energy:
		max_res = champion.get_total(Champion.Stat.ENERGY)
		resource_bar.self_modulate = Color("fff300") # Yellow
	else:
		max_res = champion.get_total(Champion.Stat.MANA)
		resource_bar.self_modulate = Color("1a75ff") # Blue
	
	if max_res > 0:
		resource_bar.visible = true
		resource_bar.max_value = max_res
		resource_bar.value = champion.current_resource
	else:
		resource_bar.visible = false
		
func _update_colors():
	if not shield_bar: return
	var target_color = Color(1, 1, 1, 1) 
	
	# 1. Determine Color by Priority
	for s in champion.active_shields:
		if s["amount"] <= 0: continue
		if s["type"] == 0:#ALL
			target_color = Color("ffffff") # Gold
		elif s["type"] == 2: # MAGIC
			target_color = Color("6C3BAA") # Purple
		elif s["type"] == 1: 
			target_color = Color("e67e22") # Orange
	shield_bar.self_modulate = target_color
	
	# Optional: If you want the shield to be "Thick" and visible
	# Ensure the ShieldBar.value = current_hp + shield_amount
