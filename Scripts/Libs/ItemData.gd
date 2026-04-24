extends Resource
class_name ItemData


enum Tier { STARTER,CONSUMABLE,BASIC, EPIC, LEGENDARY,BOOTS }
@export var item_tier: Tier

@export_group("Identity")
@export var item_name: String
@export var icon: Texture2D
@export var cost: int

@export_group("Recipe")
@export var recipe: Array[ItemData] 


@export_group("Stats & Effects")
@export var stats: Dictionary = {} 
@export var effects: Array[ItemEffect] = []
var active_effect_instance: Resource = null
@export var description: String
