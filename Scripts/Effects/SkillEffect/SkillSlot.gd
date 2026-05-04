extends Node
class_name SkillSlot

var skill_data: SkillData
var current_level: int = 1 # You'll increase this when the player levels up skills
var cooldown_timer: float = 0.0

func _process(delta: float):
	if cooldown_timer > 0:
		cooldown_timer -= delta

func activate(caster: Champion, target_data: Dictionary):
	if skill_data == null: 
		DevMenu.add_log("-> FAIL: skill_data is NULL! Did you put the Resource into the inspector?")
		return 
	if not skill_data.is_target_valid(target_data, caster):
		DevMenu.add_log("-> FAIL: %s requires a valid target!"% skill_data.skill_name )
		return
		
	current_level = caster.level
	
	if cooldown_timer > 0: 
		return 
		
	var lvl_idx = clamp(current_level - 1, 0, skill_data.base_cooldown.size() - 1)
	var cost = skill_data.resource_cost[lvl_idx]
	
	# Check resources
	if "current_resource" in caster and caster.current_resource < cost:
		return 
	
	# Consume Resources & Set Cooldown
	if "current_resource" in caster:
		caster.current_resource -= cost
		
	if skill_data.get("is_auto_attack") == true and caster.has_method("get_total"):
		# Auto-attacks scale with Attack Speed (AS)
		var aps = max(0.01, caster.get_total(caster.Stat.AS)) 
		cooldown_timer = 1.0 / aps
	else:
		# Skills scale with Ability Haste (AH)
		var base_cd = skill_data.base_cooldown[lvl_idx]
		
		if caster.has_method("get_total"):
			var ah = max(0.0, caster.get_total(caster.Stat.AH))
			# The standard formula: Base Cooldown * (100 / (100 + Ability Haste))
			cooldown_timer = base_cd * (100.0 / (100.0 + ah))
		else:
			cooldown_timer = base_cd
	skill_data.execute(caster, current_level, target_data)

# ==========================================
# --- MISSING HELPER FUNCTION ADDED HERE ---
# ==========================================
func is_ready() -> bool:
	return skill_data != null and cooldown_timer <= 0.0
