extends ItemEffect
class_name RegenPotionEffect

@export_group("Regen Stats")
@export var heal_amount: float = 50.0
@export var mana_amount: float = 0.0
@export var vfx_scene: PackedScene 

@export_group("Cooldown")
@export var cooldown_seconds: float = 2.0
var last_used_time: int = 0

# Changed from void to bool!
func on_consume(owner_node: Node) -> bool:
	var current_time = Time.get_ticks_msec()
	
	# 1. Cooldown Check
	if current_time - last_used_time < (cooldown_seconds * 1000):
		var remaining = (cooldown_seconds * 1000 - (current_time - last_used_time)) / 1000.0
		DevMenu.add_log("Potion is on cooldown! (%.1fs)" % remaining)
		return false # Stop here, don't use the potion
		
	# 2. Max HP / Mana Check
	var needed_healing = false
	var needed_mana = false
	
	# Check HP (Note: Update "current_hp" and "max_hp" if your player script uses different names like "health")
	if heal_amount > 0:
		var current_hp = owner_node.get("current_health") 
		var max_hp = owner_node.get_total(Unit.Stat.HP)
		if current_hp != null and max_hp != null:
			if current_hp < max_hp:
				needed_healing = true
		else:
			needed_healing = true # Fallback if variables aren't found
			
	# Check Mana
	if mana_amount > 0:
		var current_resource = owner_node.get("current_resource")
		var max_mana = owner_node.get("Mana")
		if current_resource != null and max_mana != null:
			if current_resource < max_mana:
				needed_mana = true
		else:
			needed_mana = true
			
	# If they are full on both, block it!
	if not needed_healing and not needed_mana:
		DevMenu.add_log("Already at max HP/Mana!")
		return false 
		
	# 3. Apply Effects
	if needed_healing and owner_node.has_method("heal"):
		owner_node.heal(heal_amount)
		
	if needed_mana and owner_node.has_method("restore_mana"):
		owner_node.restore_mana(mana_amount)
		
	# 4. Play Visuals
	if vfx_scene:
		var vfx = vfx_scene.instantiate()
		owner_node.add_child(vfx)
		
	DevMenu.add_log("Consumed Potion: +%d HP, +%d Mana" % [heal_amount, mana_amount])
	
	# 5. Record the time it was used and tell the inventory it was successful
	last_used_time = current_time
	return true
