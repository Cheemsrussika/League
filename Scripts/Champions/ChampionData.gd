extends Resource
class_name ChampionData

@export_group("Identity")
@export var champion_name: String
@export var portrait: Texture2D
# NEW: Drag the scene with Sprite2D/AnimationPlayer here
@export var visual_scene: PackedScene 
@export_group("RPG Classification")
@export var primary_classes: Array[ItemData.ItemClass] = []
@export_group("Skills")
@export var champion_passive: ChampionPassive
@export var auto_attack_sequence: Array[SkillData] = []
@export var q_skill: SkillData
@export var t_skill: SkillData
@export var e_skill: SkillData
@export var r_skill: SkillData
@export var h_skill: SkillData


@export_group("Base Stats")
# NEW: This allows you to pick Mana/Energy/Fury in the inspector
@export var resource_type: Champion.ResourceType = Champion.ResourceType.MANA
@export var base_hp: float = 600.0
@export var base_resource: float = 400.0
@export var base_ad: float = 60.0
@export var base_ms: float = 340.0
@export var base_armor: float = 30.0
@export var base_mr: float = 30.0
@export var base_range: float = 175.0
@export var base_as: float = 0.625

@export_group("Growth")
@export var hp_growth: float = 80.0
@export var ad_growth: float = 3.5
@export var armor_growth: float = 3.0
# NEW: Missing from your original list
@export var mana_growth: float = 40.0
@export var mr_growth: float = 1.25
@export var as_growth_percent: float = 2.0
