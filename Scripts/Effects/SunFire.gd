extends ItemEffect
class_name EffectSunfire

@export var damage_per_second: float = 25.0
@export var range: float = 300.0
@export var tick_rate: float = 1.0 
@export var max_hp_rate:float=0.01
@export var scale_on_mob:float=1.5

var total_damage_dealt: float = 0.0

var time_accumulator: float = 0.0

func on_update(user: Champion, delta: float) -> void:
	if user.is_dead: return
	time_accumulator += delta
	
	if time_accumulator >= tick_rate:
		time_accumulator -= tick_rate
		_burn_enemies(user)

func _burn_enemies(user: Champion):
	var all_units = user.get_tree().get_nodes_in_group("unit")
	var user_max_hp = user.get_total(Unit.Stat.HP)
	var base_burn = (damage_per_second + (user_max_hp * max_hp_rate)) * tick_rate
	
	var damage_in_this_tick = 0.0

	for target in all_units:
		if target == user or target.is_dead or target.team == user.team: 
			continue
			
		var dist = user.global_position.distance_to(target.global_position)
		if dist <= range:
			# Calculate specific damage for THIS target only
			var final_damage = base_burn
			if target.unit_type != Unit.UnitType.CHAMPION:
				final_damage *= scale_on_mob
			
			var receipt = target.take_damage(final_damage, "magic", user, false)
			var actual_val = receipt["mitigated"]
			
			total_damage_dealt += actual_val
			damage_in_this_tick += actual_val
	if damage_in_this_tick > 0:
		_update_item_ui(user)

func _update_item_ui(user):
	if user.inventory:
		user.inventory.request_ui_refresh()

func get_tooltip_extra() -> String:
	return "Total Burn Damage: %d" % int(total_damage_dealt)
