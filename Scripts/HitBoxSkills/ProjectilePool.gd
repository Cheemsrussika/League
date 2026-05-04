extends Node

var pools: Dictionary = {}

func get_projectile(scene: PackedScene) -> Node2D:
	var path = scene.resource_path
	if not pools.has(path):
		pools[path] = []
		
	var pool: Array = pools[path]
	
	# --- THE FIX: Keep checking until we find a valid bullet, or run out ---
	while pool.size() > 0:
		var proj = pool.pop_back()
		
		# Check if this bullet survived the scene change!
		if is_instance_valid(proj):
			# WAKE UP COMPLETELY
			proj.process_mode = Node.PROCESS_MODE_INHERIT
			proj.visible = true
			proj.set_deferred("monitoring", true) 
			proj.set_deferred("monitorable", true)
			return proj
			
	# If the pool was empty (or all the old bullets were destroyed by a scene change), 
	# the loop finishes and we just make a brand new one!
	var new_proj = scene.instantiate()
	new_proj.set_meta("pool_path", path)
	get_tree().current_scene.add_child(new_proj)
	return new_proj

func return_projectile(proj: Node2D):
	# PUT TO SLEEP COMPLETELY
	proj.process_mode = Node.PROCESS_MODE_DISABLED
	proj.visible = false
	# Safely turn collision off so it doesn't accidentally hit things while sleeping
	proj.set_deferred("monitoring", false)
	proj.set_deferred("monitorable", false)
	
	proj.global_position = Vector2(-9999, -9999) 
	
	var path = proj.get_meta("pool_path")
	if pools.has(path):
		pools[path].append(proj)
