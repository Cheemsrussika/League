extends Resource
class_name ChampionPassive

@export_group("Identity")
@export var passive_name: String
@export var passive_icon: Texture2D
@export_multiline var description: String

# --- VIRTUAL FUNCTIONS ---

# 1. Modify stats dynamically (e.g., Gain AD based on Juggernaut items)
func apply_stat_bonuses(_champion: Node) -> void:
	pass

# 2. Setup Godot signals (if you prefer direct signal connections)
func connect_combat_hooks(_champion: Node) -> void:
	pass

# 3. Hook into your existing _trigger_passive_effects system!
func on_combat_event(_event_name: String, _context: Dictionary, _champion: Node) -> void:
	pass
