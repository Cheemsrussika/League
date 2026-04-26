extends RefCounted
class_name StatStyle

const COLORS = {
	"health": "palegreen",
	"health_regen": "yellowgreen",
	"armor": "darkkhaki",
	"magic_res": "cornflower_blue",
	"slow_res": "lightsteelblue",
	"attack_damage": "orange",
	"ability_power": "mediumpurple", # Usually purple or yellow!
	"attack_speed": "khaki",
	"move_speed": "lightcyan",
	"mana": "lightskyblue",
	"mana_regen": "skyblue",
	"energy": "gold",
	"ability_haste": "lightgray",
	"crit_chance": "crimson",
	"crit_damage": "darkred",
	"attack_range": "whitesmoke",
	"armor_pen": "sandybrown",
	"magic_pen": "plum",
	"tenacity": "tan",
	"omnivamp": "hotpink",
	"physic_vamp": "indianred",
	"life_steal": "crimson",
	"gold_gen": "gold",
	"gold": "gold",
	"spell_haste": "lightgray",
	"heal_and_shield_power": "aquamarine"
}

# Put the paths to your actual PNG files here!
const ICONS = {
	"health": "res://Icons/UI/30px-Health_icon.png",
	"health_regen": "res://Icons/UI/Health_regeneration_icon.svg",
	"armor": "res://Icons/UI/Armor_icon.svg",
	"magic_res": "res://Icons/UI/Magic_resistance_icon.svg",
	"slow_res": "res://Icons/UI/40px-Slow_immune_2.png",
	"attack_damage": "res://Icons/UI/Attack_damage_icon.svg",
	"ability_power": "res://Icons/UI/Ability_power_icon.svg", # Usually purple or yellow!
	"attack_speed": "res://Icons/UI/30px-Attack_speed_icon.png",
	"move_speed": "res://Icons/UI/30px-Movement_speed_icon.png",
	"mana": "res://Icons/UI/Mana_icon.svg",
	"mana_regen": "res://Icons/UI/Mana_regeneration_icon.svg",
	"energy": "res://Icons/UI/Energy_icon.svg",
	"ability_haste": "res://Icons/UI/30px-Cooldown_reduction_icon.png",
	"crit_chance": "res://Icons/UI/30px-Critical_strike_chance_icon.png",
	"crit_damage": "res://Icons/UI/30px-Critical_strike_damage_icon.png",
	"attack_range": "res://Icons/UI/28px-Range_icon.png",
	"armor_pen": "res://Icons/UI/Armor_penetration_icon.svg",
	"magic_pen":"res://Icons/UI/Magic_penetration_icon.svg",
	"tenacity": "res://Icons/UI/30px-Tenacity_icon.png",
	"omnivamp": "res://Icons/UI/Omnivamp_icon.svg",
	"physic_vamp": "res://Icons/UI/Life_steal_icon.svg",
	"life_steal": "res://Icons/UI/Life_steal_icon.svg",
	"gold_gen": "res://Icons/UI/Gold_colored_icon.svg",
	"gold": "res://Icons/UI/Gold_colored_icon.svg",
	"spell_haste": "res://Icons/UI/30px-Cooldown_reduction_icon.png",
	"heal_and_shield_power": "res://Icons/UI/30px-Heal_and_shield_power_icon.png"
}

static func get_color(stat_name: String) -> String:
	var key = stat_name.to_lower()
	return COLORS.get(key, "white")

# This generates the Godot BBCode to draw the icon inline with the text!
static func get_icon_tag(stat_name: String, size: int = 18) -> String:
	var key = stat_name.to_lower()
	if ICONS.has(key):
		# Format: [img=18x18]res://path/to/icon.png[/img]
		return "[img=%dx%d]%s[/img] " % [size, size, ICONS[key]]
	return "" # Returns empty if no icon is set yet
