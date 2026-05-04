extends ItemEffect
class_name StatElixerBuff

@export var buff_scene: PackedScene
@export var duration: float = 60.0

@export_group("Stacking Rules")
# Give each potion a unique ID (e.g., "health_elixir", "ad_potion")
@export var buff_id: String = "basic_stat_elixir" 
@export var max_stacks: int = 1

@export_group("Stat Modifications")
@export var target_stat_string: String = "attack_damage" 
@export var flat_amount: float = 15.0
@export var scaling_stat_string: String = "" 
@export var scaling_ratio: float = 0.0

func on_consume(owner_node: Node) -> void:
	if not buff_scene or not owner_node.has_node("StatusContainer"): 
		return
		
	var status_container = owner_node.get_node("StatusContainer")
	var existing_buffs = []
	
	# 1. Search for existing buffs of this exact type
	for child in status_container.get_children():
		# Check if the child has our buff_id property and if it matches
		if "buff_id" in child and child.buff_id == self.buff_id:
			existing_buffs.append(child)
			
	# 2. Check if we hit the stack limit
	if existing_buffs.size() >= max_stacks:
		# We are at max stacks! Refresh the duration instead of adding a new one.
		for buff in existing_buffs:
			if buff.has_method("refresh_duration"):
				buff.refresh_duration(duration)
				
		DevMenu.add_log("Max stacks reached! Refreshed duration for: " + buff_id)
		return # EXIT HERE so we don't spawn a new buff!

	# 3. If under the limit, spawn a new buff
	var buff_instance = buff_scene.instantiate()
	
	# Inject the ID into the instance so we can find it next time
	buff_instance.set("buff_id", buff_id)
	
	if buff_instance.has_method("initialize_buff"):
		buff_instance.initialize_buff(
			duration, 
			target_stat_string, 
			flat_amount, 
			scaling_stat_string, 
			scaling_ratio
		)
	
	status_container.add_child(buff_instance)
	DevMenu.add_log("Consumed potion. Added new stack for " + target_stat_string)
