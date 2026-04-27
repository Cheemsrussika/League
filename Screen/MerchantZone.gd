# MerchantZone.gd (Attach this to your Merchant Area in the world)
extends Area2D
@export var shop_type:String ="shop_zone"
# Each merchant in the world can now have their own unique list of items!
@export var available_items: Array[ItemData]

func _ready():
	# Make sure it's in the group so the player can find it
	add_to_group(shop_type)
