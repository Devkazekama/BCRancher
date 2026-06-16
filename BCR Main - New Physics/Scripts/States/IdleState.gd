extends State
class_name IdleState

func enter(target_node: Node2D = null) -> void:
	pet.linear_velocity.x = 0
	pet.state_timer = randf_range(1.0, 4.0)
	pet._play_flavor_idle()

func process_state(delta: float) -> void:
	pet.state_timer -= delta

	if pet.state_timer <= 0:
		var energy_pct = (pet.data.current_energy / pet.data.max_energy) * 100.0
		var roll = randf()
		if roll < pet.data.action_chance_wander:
			pet.state_machine.change_state("WanderState")
		elif roll < (pet.data.action_chance_wander + pet.data.action_chance_nap) and energy_pct < 80.0:
			pet.state_machine.change_state("FindingBedState")
		else:
			pet.state_timer = randf_range(2.0, 5.0)
			pet._play_flavor_idle()
