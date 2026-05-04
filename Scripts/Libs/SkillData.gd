# res://Skills/SkillData.gd
extends Resource
class_name SkillData
enum TargetType { ENEMY, ALLY, ANY, SELF_ONLY }
@export_group("Identity")
@export var skill_name: String = ""
@export var icon: Texture2D
@export_group("Targeting Logic")
@export var is_auto_attack: bool = false
## If true, can be cast on empty ground.
@export var target_ground: bool = false
## If true, can target enemy units.
@export var target_enemies: bool = true
## If true, can target friendly units.
@export var target_allies: bool = false
## If true, can be cast on yourself.
@export var target_self: bool = false
@export var cast_range: float = 400.0
@export_group("On-Hit Settings ")
@export var is_on_hit: bool = false
@export var allow_lifesteal: bool = false
@export var on_hit_multiplier: float = 1.0
@export_group("Scaling & Costs")
@export var base_cooldown: Array[float] = [10.0, 9.0, 8.0, 7.0, 6.0]
@export var resource_cost: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]

@export_group("Effects")
# This is the LEGO way. You drag-and-drop Effect resources here.
@export var effects: Array[SkillEffect] = []

func execute(caster: Node2D, skill_level: int, target_data: Dictionary):
	# Optional: Inject current cost into target_data so effects can use it
	var idx = clamp(skill_level - 1, 0, resource_cost.size() - 1)
	target_data["final_cost"] = resource_cost[idx]
	for effect in effects:
		if effect:
			effect.on_execute(caster, skill_level, target_data, self)
# Inside SkillData.gd
func is_target_valid(target_data: Dictionary, caster: Node2D) -> bool:
	var unit = target_data.get("target_unit")
	var has_pos = target_data.has("target_position")

	# 1. SELF Check
	if target_self and unit == caster:
		return true

	# 2. UNIT Check (If we clicked on someone)
	if is_instance_valid(unit) and not unit.is_dead:
		# Check if enemy
		if target_enemies and unit.team != caster.team:
			return true
		# Check if ally
		if target_allies and unit.team == caster.team:
			return true

	# 3. GROUND Check (If we clicked ground and ground-casting is allowed)
	if target_ground and has_pos:
		# Ground casting usually doesn't care who the 'unit' is
		return true
			
	return false
