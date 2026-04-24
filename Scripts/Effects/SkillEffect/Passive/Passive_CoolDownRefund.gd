extends SkillEffect # Or whatever your base passive class is
class_name Passive_CooldownRefund

@export var skill_slot: int = 0
@export var refund_per_hit: float = 1.0
@export var require_basic_attack: bool = true

func on_damage_dealt(user: Champion, context: Dictionary) -> void:
	# 1. Filter by category (from your deal_damage func)
	if require_basic_attack and context.get("category") != "attack":
		return
	
	# 2. Get the skill and reduce cooldown
	# Assuming your Champion has a way to get skills by index
	var skill = user.get_skill_by_slot(skill_slot) 
	if skill and skill.current_cooldown > 0:
		skill.current_cooldown = max(0, skill.current_cooldown - refund_per_hit)
