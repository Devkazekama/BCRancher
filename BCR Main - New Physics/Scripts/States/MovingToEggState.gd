extends State
class_name MovingToEggState

func enter(target_node: Node2D = null) -> void:
	pet.target_node = target_node
	if pet.target_node: pet.target_node.is_being_roosted = true
	if pet.anim_sprite: pet.anim_sprite.play("walk")

func exit() -> void:
	if pet.target_node and is_instance_valid(pet.target_node):
		pet.target_node.is_being_roosted = false

func process_state(delta: float) -> void:
	if not is_instance_valid(pet.target_node):
		pet.state_machine.change_state("IdleState")
		return

	pet._move_towards_target_x(pet.target_node.global_position.x)
	if abs(pet.global_position.x - pet.target_node.global_position.x) < 10:
		pet.state_machine.change_state("RoostingState", pet.target_node)
