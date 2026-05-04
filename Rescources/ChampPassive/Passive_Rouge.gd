extends ChampionPassive
class_name  Passive_Rouge
func on_combat_event(event_name: String, context: Dictionary, champion: Node) -> void:
	if event_name == "on_damage_dealt":
		var target = context.get("target")
		if not target or not target is Unit: return
		
		var multiplier = 1.0
		
		# 1. Check Classification (The "Guren" Logic)
		if target.unit_classification == Unit.UnitClassification.BOSS:
			multiplier += 0.15 # 15% bonus damage to Bosses
			
		# 2. Check Tags (The "Exorcist" Logic)
		if target.has_tag("Undead"):
			multiplier += 0.10 # 10% bonus damage to Undead
			
		context["amount"] *= multiplier
