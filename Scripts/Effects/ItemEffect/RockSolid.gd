extends ItemEffect
class_name EffectRockSolid

@export var base_reduction: float = 5.0 
@export var hp_scaling: float = 0.0035 
@export var max_reduction_percent: float = 0.40 

func on_incoming_damage(user: Champion, data: Dictionary) -> void:
	if data.get("category") != "attack":
		return
	if data.get("type") == "true":
		return
	var max_hp = user.get_total(Champion.Stat.HP)
	var flat_reduction = base_reduction + (max_hp * hp_scaling)

	var incoming_damage = data["amount"]
	var cap = incoming_damage * max_reduction_percent
	
	var final_reduction = min(flat_reduction, cap)
	data["amount"] = max(0.0, incoming_damage - final_reduction)
	print(data["amount"])
	
