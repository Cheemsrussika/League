extends ChampionPassive
class_name PassiveSniper

func apply_stat_bonuses(champion: Node) -> void:
	var marksman_items = 0
	
	if champion.inventory:
		for item in champion.inventory.items:
			if item and item.has_method("has_class") and item.has_class(ItemData.ItemClass.MARKSMAN):
				marksman_items += 1
				
	if marksman_items > 0:
		champion.modify_stat("attack_damage", 10.0 * marksman_items)
func on_combat_event(event_name: String, context: Dictionary, champion: Node) -> void:
	if event_name == "on_attack":
		var target = context.get("target")
		if not target: return
		
		# Calculate bonus math
		var missing_hp = target.get_total(champion.Stat.HP) - target.current_health
		var bonus_dmg = missing_hp * 0.05
		
		if context.has("buckets"):
			var b = context["buckets"]
			# SAFE WAY: Get the current value (or 0.0 if it doesn't exist) and add to it
			b["magic"] = b.get("magic", 0.0) + bonus_dmg
			
		elif context.has("damage"):
			context["damage"] += bonus_dmg
