extends Resource
class_name ItemData

# Inside ItemData.gd
@export var is_unique_item: bool = false 
# Added QUEST_ITEM type
enum ItemType { EQUIPMENT, MATERIAL, CONSUMABLE, QUEST_ITEM }
@export var item_type: ItemType = ItemType.EQUIPMENT
enum Tier { STARTER, CONSUMABLE, BASIC, EPIC, LEGENDARY, BOOTS }
@export var item_tier: Tier

@export_group("Identity")
@export var item_name: String
@export var icon: Texture2D
@export var cost: int
# New property for your quest items
@export var can_be_dropped: bool = true 
@export var can_be_sold: bool = true

@export_group("Recipe")
@export var recipe: Array[ItemData] 

@export_group("Stats & Effects")
@export var stats: Dictionary = {} 
@export var effects: Array[ItemEffect] = []
var active_effect_instance: Resource = null
@export_multiline var description: String # Multiline makes it easier to write

# Helper function to check if we can get rid of it
func is_locked() -> bool:
	return item_type == ItemType.QUEST_ITEM or not can_be_dropped
