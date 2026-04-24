extends StatusEffect

func on_apply(unit):
	type = "flag"
	# Unit.gd usually checks 'has_status("grevious_wounds")' directly in heal() function
	# so we just need to exist.
