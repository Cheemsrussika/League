extends Node

@export var duration: float = 60.0 
@export var reflect_damage: float = 20.0

func _ready():
	# Just handle the timer deleting this node
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	timer.start()

# Because this is in StatusContainer, YOUR take_damage function will call this automatically!
func on_take_damage(user: Champion, context: Dictionary) -> void:
	var source = context.get("attacker")
	
	if is_instance_valid(source) and source.has_method("take_damage"):
		# Reflect damage back at the attacker
		source.take_damage(reflect_damage, "magic", user, false, "item_effect")
		DevMenu.add_log("Elixir reflected %d damage!" % reflect_damage)
