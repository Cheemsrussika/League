extends Node

var database: Dictionary = {
	"magic_tome":"res://Item/Basic/AmpliftingTome.tres",
	"hp_pot":"res://Consumable item/HealthPot.tres",
	"ice_chunk":"res://Ingredients/Shop/Ice.tres",
	"stone":"res://Ingredients/Shop/Stone.tres",
	"slime_gel":"res://Ingredients/Shop/SlimeGel.tres",
	"slime_core":"res://Ingredients/Shop/SlimeCore.tres",
	"raw_iron":"res://Ingredients/Shop/rawIron.tres",
	"raw_gold":"res://Ingredients/Shop/rawGold.tres",
	"raw_copper":"res://Ingredients/Shop/rawCopper.tres",
	"coal":"res://Ingredients/Shop/Coal.tres",
	"wood_log":"res://Ingredients/Shop/WoodLog.tres",
	"leather":"res://Ingredients/Shop/Leather.tres",
	"feather":"res://Ingredients/Shop/Feather.tres",
	"lapis":"res://Ingredients/Shop/Lapis.tres",
	"iron_ingot":"res://Ingredients/Forge/IronIngot.tres",
	"gold_ingot": "res://Ingredients/Forge/Gold_Ingot.tres",
	"copper_ingot":"res://Ingredients/Forge/CopperIngot.tres",
	"rift_maker":"res://Item/Legend/RiftMaker.tres",
	"rage_blade":"res://Item/Legend/Guinsoo'sRageBlade.tres"
	
	# Add every item in your game here!
}

func get_item_resource(item_id: String) -> Resource:
	if database.has(item_id):
		return load(database[item_id])
	push_error("Item ID not found in database: " + item_id)
	return null
