extends Unit
class_name HarvestableUnit



@export_group("Harvestable")
## If > 0, the node will respawn at its original position after this many seconds.
@export var respawn_time: float = 30.0
## Display name shown in interaction prompts ("Iron Ore", "Ancient Tree")
@export var display_name: String = "Resource Node"
## Texture shown when depleted (optional)
@export var depleted_texture: Texture2D = null

@onready var sprite: Sprite2D = $Sprite2D        # The main visual
@onready var health_bar: ProgressBar = $HealthBar # Optional progress bar

var _original_texture: Texture2D = null
var _respawn_timer: SceneTreeTimer = null
var _original_position: Vector2

func _ready() -> void:
	super._ready()  # Run Unit._ready() to init stats

	unit_type = UnitType.RESOURCE  # No team, no combat AI
	team = Team.NEUTRAL

	_original_position = global_position

	if sprite:
		_original_texture = sprite.texture

	if health_bar:
		health_bar.max_value = get_total(Stat.HP)
		health_bar.value = current_health

# -----------------------------------------------------------
# Override take_damage: only accept "true" damage (tool hits)
# so stray spells don't harvest your ore veins
# -----------------------------------------------------------
func take_damage(raw_amount, dmg_type, source, is_crit, category = "spell"):
	# 1. Type Check
	if dmg_type != "true" and dmg_type != "physical":
		return {"health_lost": 0, "mitigated": 0, "shield_soaked": 0}
	
	# 2. Execute the damage logic and STORE the result
	var result = super.take_damage(raw_amount, dmg_type, source, is_crit, category)

	# 3. Visuals (Now this will actually run!)
	if FLOATING_TEXT_SCENE:
		var text_instance = FLOATING_TEXT_SCENE.instantiate()
		get_tree().current_scene.add_child(text_instance)
		# Assuming result contains a "health_lost" key based on your return type
		text_instance.start(result.health_lost, global_position, dmg_type, is_crit)
	
	# 4. Update UI
	if health_bar:
		health_bar.value = current_health

	# 5. Finally, exit the function with the result
	return result

# -----------------------------------------------------------
# Override die — no kill credit, just deplete and respawn
# -----------------------------------------------------------
func die(_killer) -> void:
	if is_dead: return
	is_dead = true

	# Emit unit_died so LootTableComponent does its job
	unit_died.emit(self)

	# Visual: swap to depleted texture
	if sprite and depleted_texture:
		sprite.texture = depleted_texture

	# Disable collision so players walk through the stump/crater
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)

	DevMenu.add_log("[HarvestableUnit] %s depleted." % display_name)

	# Schedule respawn
	if respawn_time > 0:
		_respawn_timer = get_tree().create_timer(respawn_time)
		_respawn_timer.timeout.connect(_respawn)
	else:
		queue_free()

# -----------------------------------------------------------
# Respawn: restore HP and visuals
# -----------------------------------------------------------
func _respawn() -> void:
	is_dead = false
	current_health = get_total(Stat.HP)

	if sprite and _original_texture:
		sprite.texture = _original_texture

	if health_bar:
		health_bar.max_value = get_total(Stat.HP)
		health_bar.value = current_health

	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", false)

	DevMenu.add_log("[HarvestableUnit] %s respawned." % display_name)
