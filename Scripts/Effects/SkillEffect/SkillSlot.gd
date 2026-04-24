extends Node
class_name SkillSlot

var skill_data: SkillData
var current_level: int = 1 # You'll increase this when the player levels up skills
var cooldown_timer: float = 0.0

func _process(delta: float):
	if cooldown_timer > 0:
		cooldown_timer -= delta

func activate(caster: Champion, target_data: Dictionary):
	print("1. SkillSlot received activate command!")
	
	if skill_data == null: 
		print("-> FAIL: skill_data is NULL! Did you put the Resource into the inspector?")
		return 
	current_level=caster.level
	if cooldown_timer > 0: 
		print("-> FAIL: " + skill_data.skill_name + " is on cooldown!")
		return 
		
	var lvl_idx = clamp(current_level - 1, 0, skill_data.base_cooldown.size() - 1)
	var cost = skill_data.resource_cost[lvl_idx]
	
	# Safely check mana using your Unit.gd get_total method
	# (Assuming you added a 'current_mana' variable. If not, bypass this check for now)
	if "current_mana" in caster and caster.current_mana < cost:
		print("-> FAIL: Not enough mana!")
		return 
		
	print("2. Checks passed! Setting cooldown and executing...")
	
	# Consume Resources & Set Cooldown
	if "current_mana" in caster:
		caster.current_mana -= cost
	cooldown_timer = skill_data.base_cooldown[lvl_idx]
	
	# EXECUTE!
	print("3. Calling skill_data.execute() NOW!")
	skill_data.execute(caster, current_level, target_data)
