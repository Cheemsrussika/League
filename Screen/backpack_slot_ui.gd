extends Control # Or whatever your root node type is

signal pressed # We will emit this so the GridContainer can hear it!

@onready var icon_texture = $IconTexture
@onready var amount_label = $AmountLabel
@onready var click_button = $Button # Your invisible button

func _ready():
	# Pass the click from the invisible button up to the panel
	click_button.pressed.connect(func(): pressed.emit())

func set_item(slot_data):
	if slot_data == null:
		icon_texture.texture = null
		amount_label.text = ""
	else:
		icon_texture.texture = slot_data.item.icon
		
		# Only show numbers if there is more than 1 item!
		if slot_data.amount > 1:
			print(slot_data.amount)
			amount_label.text = str(slot_data.amount)
		else:
			amount_label.text = ""
