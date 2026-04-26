# res://Skills/Effects/SkillEffect.gd
extends Resource
class_name SkillEffect

# Using Node2D instead of Champion fixes the signature error/circular loop
func on_execute(_caster: Node2D, _skill_level: int, _target_data: Dictionary, _skill_data: Resource) -> void:
	pass
