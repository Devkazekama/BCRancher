extends State
class_name EatingState

func enter(target_node: Node2D = null) -> void:
	pet.target_node = target_node
	pet.linear_velocity.x = 0
	pet.state_timer = 2.0 * pet.data.evolution_tier
	if pet.anim_sprite: pet.anim_sprite.play("eat")

func process_state(delta: float) -> void:
	pet.state_timer -= delta

	if pet.state_timer <= 0:
		if is_instance_valid(pet.target_node) and not pet.target_node.is_queued_for_deletion():
			if pet.target_node.is_in_group("feeder") and pet.target_node.has_method("consume_food"):
				if pet.target_node.consume_food():
					pet._fill_hunger_and_check_egg()
			elif pet.target_node.is_in_group("food"):
				pet.target_node.queue_free()
				pet._fill_hunger_and_check_egg()
		pet.state_machine.change_state("IdleState")
