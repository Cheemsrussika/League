extends RichTextLabel

var champion: Champion

func _ready():
	bbcode_enabled = true


func _process(_delta):
	if is_instance_valid(champion):
		set_process(false)
		return
	if is_instance_valid(GameManager.player_champion):
		champion = GameManager.player_champion
		_setup_connection()

func _setup_connection():
	print("UI: Found Champion ", champion.name)
	if champion.has_signal("stats_updated"):
		champion.stats_updated.connect(_update_text)
		champion._refresh_ui_display()
	else:
		print("Error: Champion is missing 'stats_updated' signal")

func _update_text(new_text: String):
	text = new_text
