extends ItemEffect
class_name EffectEternity

# --- EXPORTS ---
@export_group("Eternity Values")
@export var mana_restore_percent_damage: float = 0.15 
@export var health_restore_percent_cost: float = 0.20
@export var health_restore_cap_per_cast: float = 15.0 

# --- TRACKING ---
var total_mana_restored: float = 0.0
var total_health_restored: float = 0.0

func on_hit_received_pre_mitigation(user: Champion, context: Dictionary) -> void:
	var damage_taken = context.get("amount", 0.0)
	if damage_taken <= 0: return
	var mana_to_restore = damage_taken * mana_restore_percent_damage
	user.restore(mana_to_restore, 0.0) 
	total_mana_restored += mana_to_restore
func on_ability_activated(user: Champion, context: Dictionary) -> void:
	var cost = context.get("mana_cost", 0.0)
	if cost == 0.0 and context.has("ability_id"):
		var ability = user.get_ability(context["ability_id"])
		if ability and "mana_cost" in ability:
			cost = ability.mana_cost

	# Validation
	if cost <= 0: return
	if context.get("is_toggle", false): return
	var heal_amount = cost * health_restore_percent_cost
	heal_amount = min(heal_amount, health_restore_cap_per_cast)
	user.heal(heal_amount)
	total_health_restored += heal_amount
	if user.inventory: user.inventory.request_ui_refresh()
func get_tooltip_extra() -> String:
	var text = ""
	if total_mana_restored > 0:
		text += "Mana Restored: %d\n" % int(total_mana_restored)
	if total_health_restored > 0:
		text += "Health Restored: %d" % int(total_health_restored)
		
	return text
