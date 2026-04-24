# res://Skills/SkillData.gd
extends Resource
class_name SkillData
enum TargetType { ENEMY, ALLY, ANY, SELF_ONLY }
@export_group("Identity")
@export var skill_name: String = ""
@export var icon: Texture2D
@export_group("Target")
@export var targeting: TargetType = TargetType.ENEMY
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
	for effect in effects:
		if effect:
			effect.on_execute(caster, skill_level, target_data, self)
