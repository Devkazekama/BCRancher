extends State
class_name RoostingState

func enter(target_node: Node2D = null) -> void:
	pet.target_node = target_node
	pet.linear_velocity.x = 0
	pet.state_timer = 10.0
	if pet.anim_sprite: pet.anim_sprite.play("sleep")

	if pet.target_node and is_instance_valid(pet.target_node):
		pet.target_node.is_being_roosted = true

func exit() -> void:
	if pet.target_node and is_instance_valid(pet.target_node):
		pet.target_node.is_being_roosted = false

func process_state(delta: float) -> void:
	pet.state_timer -= delta

	if pet.state_timer <= 0 or not is_instance_valid(pet.target_node):
		pet.state_machine.change_state("IdleState")
