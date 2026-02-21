extends ItemEffect
class_name EffectOnLevelUp

@export_group("Eternity Values")
@export var mana_restore_percent: float = 0.2
@export var health_restore_percent: float = 0.2

func on_level_up(user: Champion, context: Dictionary) -> void:
	var max_mana = user.get_total(Champion.Stat.MANA)
	var max_hp = user.get_total(Champion.Stat.HP)
	var mana_to_restore = 0.0
	var health_to_restore = 0.0
	if mana_restore_percent > 0:
		mana_to_restore = max_mana * mana_restore_percent
	if health_restore_percent > 0:
		health_to_restore = max_hp * health_restore_percent
	user.restore(mana_to_restore, health_to_restore)
	
