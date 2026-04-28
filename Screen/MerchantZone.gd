# MerchantZone.gd (Attach this to your Merchant Area in the world)
extends Area2D
@export var shop_type:String ="shop_zone"
@export var size_w:float=1.0
@export var size_h:float=1.0
@export var available_items: Array[ItemData]
@onready var shape=$CollisionShape2D
func _ready():
	shape.apply_scale(Vector2(size_w,size_h))
	add_to_group(shop_type)
