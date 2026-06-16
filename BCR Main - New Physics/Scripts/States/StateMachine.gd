extends Node
class_name StateMachine

var current_state: State
var pet: Pet

func _ready() -> void:
	pet = get_parent() as Pet

	for child in get_children():
		if child is State:
			child.pet = pet

	if get_child_count() > 0:
		current_state = get_child(0) as State
		current_state.enter()

func change_state(new_state_name: String, target_node: Node2D = null) -> void:
	var new_state = get_node_or_null(new_state_name) as State
	if new_state == null or new_state == current_state:
		return

	if current_state:
		current_state.exit()

	current_state = new_state
	current_state.enter(target_node)

func process_machine(delta: float) -> void:
	if current_state:
		current_state.process_state(delta)
