extends Node
class_name StatusLibrary 

# Register your Status Scripts here
const STAT_BUFF    = preload("res://StatusEffects/StatusStatBuff.gd") # The ultimate stat LEGO
const BURN         = preload("res://StatusEffects/StatusBurn.gd")
const GENERIC_SLOW = preload("res://StatusEffects/StatusGenericSlow.gd")
const GRIEVOUS     = preload("res://StatusEffects/StatusGrievous.gd")
const FLAG         = preload("res://StatusEffects/StatusFlag.gd") 
const BLEED        = preload("res://StatusEffects/StatusBleed.gd")
const EMPOWER      = preload("res://StatusEffects/Status_On_Hit.gd")

static func get_effect_script(id: String):
	match id:
		# --- 1. THE DYNAMIC STAT MODIFIERS ---
		# ALL of these just use the single STAT_BUFF script now!
		"stat_buff","doran_ring","Spectral Waltz","kill_tracker_buff", "Phage", "SUFFERING", "shojin", "skill_speed","LichBane", "skill_stats", "skill_stats1", "rage_speed", "Kraken", "conqueror", "stacking_buff", "riftmaker_ramp", "MADNESS", "rageblade","armor_shred","rage_speed", "frozen_heart", "abyssal_curse": 
			return STAT_BUFF
		
		# --- 2. THE UNIQUE MECHANICS ---
		"generic_slow", "ice_slow", "skill_slow": 
			return GENERIC_SLOW
			
		"Lindrys", "item_burn", "bleed": 
			return BURN
			
		"grevious_wounds": 
			return GRIEVOUS
			
		"sheen_proc_active", "flag": 
			return FLAG
			
		"yuntal_bleed": 
			return BLEED
			
		"empowered_hit": 
			return EMPOWER
	
		_:
			print("StatusLibrary: ID '%s' not found!" % id)
			return null
