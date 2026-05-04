extends Node

var database: Dictionary = {
	"magic_tome":"res://Item/Basic/AmpliftingTome.tres",
	"hp_pot":"res://Consumable item/HealthPot.tres"
	# Add every item in your game here!
}

func get_item_resource(item_id: String) -> Resource:
	if database.has(item_id):
		return load(database[item_id])
	push_error("Item ID not found in database: " + item_id)
	return null
