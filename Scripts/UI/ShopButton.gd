extends Button

@export var item_to_sell: ItemData
@export var player: Champion

func _pressed():
	if player and player.inventory:
		player.inventory.try_purchase(player,item_to_sell)
