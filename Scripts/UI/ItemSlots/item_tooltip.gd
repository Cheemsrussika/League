extends Control

@onready var label: RichTextLabel = $"." 

var current_item: ItemData = null 

func _ready():
	# Make sure BBCode is enabled in code just in case!
	label.bbcode_enabled = true
	hide()

func _process(_delta):
	if visible and current_item:
		update_tooltip_text()

func display(item: ItemData):
	current_item = item
	update_tooltip_text() 
	show()

func hide_tooltip(): 
	current_item = null
	hide()

func update_tooltip_text():
	if not current_item: return
	
	# 1. Header (Centered, Golden Name, Yellow Cost)
	var text = "[center][b][color=gold]%s[/color][/b][/center]\n" % current_item.item_name
	text += "[center][color=khaki]Cost: %d Gold[/color][/center]\n" % current_item.cost
	text += "[color=gray]------------------------[/color]\n"
	
	# 2. Base Stats (Clean formatting: "+10 Attack Damage")
	if current_item.stats and current_item.stats.size() > 0:
		for stat_key in current_item.stats:
			var val = current_item.stats[stat_key]
			var formatted_name = stat_key.replace("_", " ").capitalize()
			# Aquamarine is a great "Stat" color
			text += "[color=aquamarine]+%s %s[/color]\n" % [str(val), formatted_name]
		text += "[color=gray]------------------------[/color]\n"


	# 4. Dynamic Passives / Stacks (Real-time updates)
	var extra_stats_text = ""
	if current_item.effects:
		for effect in current_item.effects:
			if effect.has_method("get_tooltip_extra"):
				var stats = effect.get_tooltip_extra()
				if stats != "":
					extra_stats_text += "\n[color=orange]Passive:[/color] " + stats

	if extra_stats_text != "":
		text += extra_stats_text
	
	label.text = text
