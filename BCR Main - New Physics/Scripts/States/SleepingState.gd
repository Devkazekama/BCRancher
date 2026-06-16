extends State
class_name SleepingState

func enter(target_node: Node2D = null) -> void:
	pet.linear_velocity.x = 0
	if pet.anim_sprite: pet.anim_sprite.play("sleep")

func process_state(delta: float) -> void:
	var energy_pct = (pet.data.current_energy / pet.data.max_energy) * 100.0
	if energy_pct >= 100.0:
		pet.state_machine.change_state("IdleState")
