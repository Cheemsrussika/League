extends ChampionPassive
class_name PassiveClassTest

func on_combat_event(event_name: String, context: Dictionary, _champion: Node) -> void:
	if event_name == "on_attack":
		var target = context.get("target")
		if not target or not target is Unit: return
		
		# 1. Test for Mage
		if target.has_tag("MAGE"):
			DevMenu.add_log("TEST: Hitting a Mage! Applying silence logic...")
			# Example: context["damage"] *= 1.5
			
		# 2. Test for Rogue/Assassin
		if target.has_tag("undead") or target.has_tag("ROGUE"):
			DevMenu.add_log("TEST: Hitting a slippery target! +20 Accuracy.")

		# 3. Test for Minions vs Champions
		if target.unit_type == Unit.UnitType.MINION:
			DevMenu.add_log("TEST: This is just a minion.")
