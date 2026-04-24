extends Control

@onready var label: RichTextLabel = $"."

var current_item: ItemData = null # Store the item being viewed

func _ready():
	hide()

func _process(_delta):
	# Only update if the panel is visible and we have an item to show
	if visible and current_item:
		update_tooltip_text()

func display(item: ItemData):
	current_item = item
	update_tooltip_text() # Initial render
	show()

func hide_tooltip(): # Renamed from hide to avoid conflict with built-in
	current_item = null
	hide()

# Moved the logic to its own function so _process can call it
func update_tooltip_text():
	if not current_item: return
	
	var text = "[b]%s[/b]\n" % current_item.item_name
	text += "[color=yellow]Cost: %d[/color]\n" % current_item.cost
	text += "----------------\n"
	text += current_item.description
	
	var extra_stats_text = ""
	
	if current_item.effects:
		for effect in current_item.effects:
			if effect.has_method("get_tooltip_extra"):
				var stats = effect.get_tooltip_extra()
				if stats != "":
					extra_stats_text += "\n" + stats

	if extra_stats_text != "":
		text += "\n\n[color=orange]" + extra_stats_text + "[/color]"
	
	label.text = text
