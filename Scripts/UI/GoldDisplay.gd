extends Label

var champion: Champion

func _ready():

	pass

func _process(_delta):
	if is_instance_valid(champion):
		set_process(false) 
		return
	if is_instance_valid(GameManager.player_champion):
		champion = GameManager.player_champion
		_setup_connection()

func _setup_connection():
	print("Gold UI: Found Champion ", champion.name)
	
	if champion.has_signal("gold_updated"):
		champion.gold_updated.connect(_on_gold_updated)
		_on_gold_updated(champion.gold)
	else:
		print("Error: Champion is missing 'gold_updated' signal")

func _on_gold_updated(amount: float):
	text = "GOLD: %.0f" % [amount]
