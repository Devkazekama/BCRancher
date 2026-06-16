extends State
class_name MovingToFeederState

func enter(target_node: Node2D = null) -> void:
	pet.target_node = target_node
	if pet.anim_sprite: pet.anim_sprite.play("walk")

func process_state(delta: float) -> void:
	if not is_instance_valid(pet.target_node) or pet.target_node.is_queued_for_deletion():
		pet.state_machine.change_state("IdleState")
		return

	var target_x = pet.target_node.global_position.x
	if pet.target_node.has_node("EatPosition"):
		target_x = pet.target_node.get_node("EatPosition").global_position.x
	pet._move_towards_target_x(target_x)

	if abs(pet.global_position.x - target_x) < 5:
		pet.state_machine.change_state("EatingState", pet.target_node)
