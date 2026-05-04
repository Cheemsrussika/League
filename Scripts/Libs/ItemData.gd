extends Resource
class_name ItemData

# --- ENUMS ---
enum ItemType { EQUIPMENT, MATERIAL, CONSUMABLE, QUEST_ITEM }
enum Tier { STARTER, CONSUMABLE, BASIC, EPIC, LEGENDARY, BOOTS }

# NEW: RPG Class Tags! Expand this list to fit your game's unique builds.
enum ItemClass {
	NONE,
	MAGE,
	ASSASSIN,
	JUGGERNAUT,
	MARKSMAN,
	BRUISER,
	TANK,
	SUPPORT,
	ENCHANTER,
	ROGUE
}

@export var is_unique_item: bool = false 
@export var item_type: ItemType = ItemType.EQUIPMENT
@export var item_tier: Tier

@export_group("Identity")
@export var item_id: String = "" # e.g., "basic_sword", "health_potion"	
@export var item_name: String
@export var icon: Texture2D
@export var cost: int
@export var can_be_dropped: bool = true 
@export var can_be_sold: bool = true

# NEW: The array that holds all the RPG tags for this item.
@export var item_classes: Array[ItemClass] = []

@export_group("Recipe")
@export var recipe: Array[ItemData] 

@export_group("Stats & Effects")
@export var stats: Dictionary = {} 
@export var effects: Array[ItemEffect] = []
var active_effect_instance: Resource = null
@export_multiline var description: String 

# Helper function to check if we can get rid of it
func is_locked() -> bool:
	return item_type == ItemType.QUEST_ITEM or not can_be_dropped

# Helper function to check if the item has a specific class tag
func has_class(target_class: ItemClass) -> bool:
	return item_classes.has(target_class)
