extends HBoxContainer

## One row in the PickupListPanel scroll list.
## Scene layout (HBoxContainer):
##   TextureRect ($Icon) | Label ($NameLabel) | Label ($AmountLabel) | Button ($PickupButton)

signal pickup_requested

@onready var icon_rect: TextureRect = $Icon
@onready var name_label: Label = $NameLabel
@onready var amount_label: Label = $AmountLabel
@onready var pickup_button: Button = $PickupButton

func _ready() -> void:
	pickup_button.pressed.connect(func(): pickup_requested.emit())

func setup(item: ItemData, amount: int) -> void:
	if item.icon:
		icon_rect.texture = item.icon

	name_label.text = item.item_name

	if amount > 1:
		amount_label.text = "x%d" % amount
	else:
		amount_label.text = ""

	# Colour-code by tier if you want — optional
	match item.item_tier:
		ItemData.Tier.EPIC:     name_label.modulate = Color.MEDIUM_PURPLE
		ItemData.Tier.LEGENDARY: name_label.modulate = Color.GOLD
		_:                      name_label.modulate = Color.WHITE
