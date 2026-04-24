extends Label

@onready var champion = get_parent()

func _process(_delta):
	if is_instance_valid(champion) and "gold" in champion:
		text = "%d G" % int(champion.gold)
	else:
		text = "0 G"
