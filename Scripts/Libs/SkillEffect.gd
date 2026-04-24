# res://Skills/Effects/SkillEffect.gd
extends Resource
class_name SkillEffect

# Using Node2D instead of Champion fixes the signature error/circular loop
func on_execute(caster: Node2D, skill_level: int, target_data: Dictionary, skill_data: Resource) -> void:
	pass
