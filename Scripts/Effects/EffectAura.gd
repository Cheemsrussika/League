extends ItemEffect
class_name EffectAuraItem

@export_group("Aura Config")
@export var status_id: String = "abyssal_curse"
@export var aura_range: float = 700.0
@export var aura_power: float = 0.12 # 12% for Abyssal, 0.20 for Frozen Heart

# If this is Sunfire, we toggle damage logic
@export var is_burn_aura: bool = false
@export var burn_base_dmg: float = 25.0
@export var burn_hp_ratio: float = 0.01

func on_update(user: Champion, delta: float):
	var targets = user.get_nearby_enemies(aura_range)
	
	for target in targets:
		if target.has_method("apply_status_effect"):
			target.apply_status_effect(status_id, 0.5, 1, aura_power, user)
		if is_burn_aura:
			_handle_burn(user, target, delta)

func _handle_burn(user: Champion, target: Unit, delta: float):
	var hp_scaling = user.get_total(user.Stat.HP) * burn_hp_ratio
	var damage = (burn_base_dmg + hp_scaling) * delta
	
	if target.unit_type != Unit.UnitType.CHAMPION:
		damage *= 1.5
	user.deal_damage(target, damage, "magic", "aura")
