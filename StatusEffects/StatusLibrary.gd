extends Node
class_name StatusLibrary 

# Register your Status Scripts here
const GENERIC_SLOW = preload("res://StatusEffects/StatusGenericSlow.gd")
const BURN         = preload("res://StatusEffects/StatusBurn.gd")
const SHRED        = preload("res://StatusEffects/StatusArmorShred.gd")
const STAT_BUFF    = preload("res://StatusEffects/StatusStatBuff.gd")
const GRIEVOUS     = preload("res://StatusEffects/StatusGrievous.gd")
const FLAG         = preload("res://StatusEffects/StatusFlag.gd") 
const ABYSSAL      = preload("res://StatusEffects/StatusAbyssalCurse.gd")
const FROZEN_HEART = preload("res://StatusEffects/StatusFrozenHeart.gd")
const BLEED = preload("res://StatusEffects/StatusBleed.gd")


static func get_effect_script(id: String):
	match id:
		"generic_slow": return GENERIC_SLOW
		
		"Lindrys", "item_burn", "bleed": return BURN
		
		"armor_shred": return SHRED
		
		"stat_buff","Phage","SUFFERING", "rage_speed","Kraken" ,"conqueror", "stacking_buff", "riftmaker_ramp", "MADNESS","rageblade": return STAT_BUFF
		
		"frozen_heart": return FROZEN_HEART
		
		"grevious_wounds": return GRIEVOUS
		
		"sheen_proc_active", "flag": return FLAG
		
		"abyssal_curse": return ABYSSAL
		
		"yuntal_bleed": return BLEED
	
		_:
			print("StatusLibrary: ID '%s' not found!" % id)
			return null
