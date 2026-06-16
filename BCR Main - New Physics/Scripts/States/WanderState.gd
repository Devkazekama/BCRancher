extends State
class_name WanderState

func enter(target_node: Node2D = null) -> void:
	var direction = 1 if randf() > 0.5 else -1
	pet.target_destination = Vector2(pet._get_screen_safe_x(pet.global_position.x + (direction * randf_range(50, 200))), pet.global_position.y)
	pet.state_timer = randf_range(3.0, 7.0)
	if pet.anim_sprite: pet.anim_sprite.play("walk")

func process_state(delta: float) -> void:
	pet.state_timer -= delta
	pet._move_towards_target_x(pet.target_destination.x)

	if abs(pet.global_position.x - pet.target_destination.x) < 10 or pet.state_timer <= 0:
		pet.state_machine.change_state("IdleState")
