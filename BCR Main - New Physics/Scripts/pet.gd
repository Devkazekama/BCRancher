extends PickableItem

@export_group("Data & Loadout")
@export var data: CreatureData 
@export var egg_scene: PackedScene 

@export_group("Personality & Movement")
@export var walk_speed: float = 100.0
@export var acceleration: float = 0.1

enum State { IDLE, WANDER, SLEEPING, MOVING_TO_FEEDER, EATING, MOVING_TO_EGG, ROOSTING, FINDING_BED }
var current_state: State = State.IDLE
var state_timer: float = 0.0
var target_destination: Vector2 = Vector2.ZERO
var target_node: Node2D = null

var debug_timer: float = 0.0 
var is_walking: bool = false

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	z_index = 2
	z_as_relative = false
	super._ready()
	
	if not data:
		data = CreatureData.new()

func _physics_process(delta: float) -> void:
	# 1. Call the parent script first so gravity, mouse-follow, and self-righting run
	super._physics_process(delta)
	
	if data == null: return
	
	debug_timer += delta
	if debug_timer >= 5.0:
		debug_timer = 0.0
		var threshold = 60.0 * data.evolution_tier
		var evo_pct = (data.accumulated_rest_time / threshold) * 100.0
		print("[%s] State: %s | Hunger: %d/%d | Energy: %d/%d | Happiness: %d | Evo: %.1f%%" % [
			data.species_name, State.keys()[current_state], 
			data.current_hunger, data.max_hunger, data.current_energy, data.max_energy, data.happiness, evo_pct
		])
		
	# 2. Check the new variable name from PickableItem
	if is_grabbed:
		return
		
	_update_needs(delta)
	_evaluate_state_machine()
	_execute_current_state(delta)
	
	is_walking = (current_state == State.WANDER or current_state == State.MOVING_TO_FEEDER or current_state == State.MOVING_TO_EGG or current_state == State.FINDING_BED)

func _on_picked_up() -> void:
	super._on_picked_up()
	if current_state == State.SLEEPING or current_state == State.FINDING_BED:
		print(data.species_name, " was woken up abruptly!")
		_transition_to(State.IDLE)

func _update_needs(delta: float) -> void:
	var energy_pct = (data.current_energy / data.max_energy) * 100.0
	var hunger_pct = (data.current_hunger / data.max_hunger) * 100.0

	if current_state == State.SLEEPING:
		# Only gain energy if there is food in the belly
		if hunger_pct > 0.0:
			data.current_energy += data.rest_energy_rate * delta
		else:
			# If sleeping with 0 hunger, energy continues to drain
			data.current_energy -= data.energy_decay_rate * delta
			
		# Only gain evolution progress if deeply happy (> 80%)
		if data.happiness > 80.0:
			data.accumulated_rest_time += delta * data.evolution_rate_modifier
			_check_evolution()
	else:
		data.current_energy -= data.energy_decay_rate * delta
		data.current_hunger -= data.hunger_decay_rate * delta
		
	data.current_energy = clamp(data.current_energy, 0.0, data.max_energy)
	data.current_hunger = clamp(data.current_hunger, 0.0, data.max_hunger)
	
	# Personality-driven Happiness Logic
	if hunger_pct > 70.0 and energy_pct > 70.0:
		data.happiness += data.happiness_gain_rate * delta
	elif current_state == State.WANDER:
		data.happiness += (data.happiness_gain_rate * 0.5) * delta
	
	if energy_pct < 25.0 or hunger_pct < 25.0:
		data.happiness -= data.happiness_loss_rate * delta
		
	data.happiness = clamp(data.happiness, 0.0, 100.0)

func _evaluate_state_machine() -> void:
	if current_state == State.EATING or current_state == State.ROOSTING or current_state == State.FINDING_BED:
		return
		
	var energy_pct = (data.current_energy / data.max_energy) * 100.0
	var hunger_pct = (data.current_hunger / data.max_hunger) * 100.0
	
	# 1. ALWAYS check for food if hungry, even if sleeping or exhausted
	if hunger_pct <= 25.0:
		var food_source = _find_available_food()
		if food_source:
			_transition_to(State.MOVING_TO_FEEDER, food_source)
			return
		elif current_state != State.SLEEPING:
			# If no food exists, and we are starving, go to sleep to conserve energy
			_transition_to(State.FINDING_BED)
			return
			
	# 2. Exhaustion logic
	if energy_pct <= 25.0 and current_state != State.SLEEPING:
		_transition_to(State.FINDING_BED)
		return
		
	# 3. Wake up naturally
	if current_state == State.SLEEPING:
		if energy_pct >= 100.0:
			_transition_to(State.IDLE)
		return
		
	# 4. Roosting Logic
	if data.evolution_tier > 1 and hunger_pct > 50.0 and energy_pct > 50.0:
		if current_state != State.MOVING_TO_EGG:
			var free_egg = _find_free_egg()
			if free_egg:
				_transition_to(State.MOVING_TO_EGG, free_egg)
				return
				
	# 5. Personality-driven Idle Actions
	if current_state == State.IDLE and state_timer <= 0:
		var roll = randf()
		if roll < data.action_chance_wander:
			_transition_to(State.WANDER)
		elif roll < (data.action_chance_wander + data.action_chance_nap) and energy_pct < 80.0: 
			_transition_to(State.FINDING_BED)
		else:
			# Reset idle timer and pick a random "flavor" animation (pecking, resting, idle)
			state_timer = randf_range(2.0, 5.0)
			_play_flavor_idle()
			
	if current_state == State.WANDER and state_timer <= 0:
		_transition_to(State.IDLE)

func _transition_to(new_state: State, target: Node2D = null) -> void:
	if current_state == new_state: return
	
	if current_state == State.ROOSTING and target_node and is_instance_valid(target_node):
		target_node.is_being_roosted = false
	current_state = new_state
	target_node = target
	
	match current_state:
		State.IDLE:
			linear_velocity.x = 0
			state_timer = randf_range(1.0, 4.0)
			_play_flavor_idle()
		State.WANDER:
			var direction = 1 if randf() > 0.5 else -1
			target_destination = Vector2(_get_screen_safe_x(global_position.x + (direction * randf_range(50, 200))), global_position.y)
			state_timer = randf_range(3.0, 7.0)
			if anim_sprite: anim_sprite.play("walk")
		State.FINDING_BED:
			var direction = 1 if randf() > 0.5 else -1
			target_destination = Vector2(_get_screen_safe_x(global_position.x + (direction * randf_range(60, 150))), global_position.y)
			state_timer = 5.0 
			if anim_sprite: anim_sprite.play("walk")
		State.SLEEPING:
			linear_velocity.x = 0
			if anim_sprite: anim_sprite.play("sleep")
		State.MOVING_TO_FEEDER:
			if anim_sprite: anim_sprite.play("walk")
		State.EATING:
			linear_velocity.x = 0
			state_timer = 2.0 * data.evolution_tier 
			if anim_sprite: anim_sprite.play("eat")
		State.MOVING_TO_EGG:
			if target_node: target_node.is_being_roosted = true
			if anim_sprite: anim_sprite.play("walk")
		State.ROOSTING:
			linear_velocity.x = 0
			state_timer = 10.0 
			if anim_sprite: anim_sprite.play("sleep") 

func _play_flavor_idle() -> void:
	if not anim_sprite: return
	var flavor_anims = ["idle", "idle", "idle", "idle", "eat"]
	anim_sprite.play(flavor_anims.pick_random())

func _execute_current_state(delta: float) -> void:
	state_timer -= delta
	
	match current_state:
		State.WANDER, State.FINDING_BED:
			_move_towards_target_x(target_destination.x)
			if abs(global_position.x - target_destination.x) < 10 or state_timer <= 0:
				if current_state == State.FINDING_BED:
					_transition_to(State.SLEEPING)
				else:
					_transition_to(State.IDLE)
					
		State.MOVING_TO_FEEDER:
			if not is_instance_valid(target_node) or target_node.is_queued_for_deletion():
				_transition_to(State.IDLE)
				return
				
			var target_x = target_node.global_position.x
			if target_node.has_node("EatPosition"):
				target_x = target_node.get_node("EatPosition").global_position.x
			_move_towards_target_x(target_x)
			if abs(global_position.x - target_x) < 5: 
				_transition_to(State.EATING, target_node)
				
		State.EATING:
			if state_timer <= 0:
				if is_instance_valid(target_node) and not target_node.is_queued_for_deletion():
					if target_node.is_in_group("feeder") and target_node.has_method("consume_food"):
						if target_node.consume_food():
							_fill_hunger_and_check_egg()
					elif target_node.is_in_group("food"):
						target_node.queue_free()
						_fill_hunger_and_check_egg()
				_transition_to(State.IDLE)
				
		State.MOVING_TO_EGG:
			if not is_instance_valid(target_node):
				_transition_to(State.IDLE)
				return
				
			_move_towards_target_x(target_node.global_position.x)
			if abs(global_position.x - target_node.global_position.x) < 10:
				_transition_to(State.ROOSTING, target_node)
				
		State.ROOSTING:
			if state_timer <= 0 or not is_instance_valid(target_node):
				_transition_to(State.IDLE)

func _get_screen_safe_x(desired_x: float) -> float:
	var viewport_rect = get_viewport_rect()
	return clamp(desired_x, 50.0, viewport_rect.size.x - 50.0)

func _move_towards_target_x(target_x: float) -> void:
	var direction = sign(target_x - global_position.x)
	# Use linear_velocity instead of velocity for RigidBody2D
	linear_velocity.x = lerp(linear_velocity.x, direction * data.walk_speed, acceleration)
	if anim_sprite: anim_sprite.flip_h = (direction < 0)
	
func _find_available_food() -> Node2D:
	var feeders = get_tree().get_nodes_in_group("feeder")
	for f in feeders:
		if f.get("food_stock") != null and f.food_stock > 0:
			return f
	var loose_food = get_tree().get_nodes_in_group("food")
	for food in loose_food:
		if is_instance_valid(food) and not food.is_queued_for_deletion():
			# Check for is_grabbed instead of is_dragging
			if food.get("is_grabbed") == false and food.get("is_attached") == false:
				return food
	return null

func _find_free_egg() -> Node2D:
	var eggs = get_tree().get_nodes_in_group("egg")
	for e in eggs:
		if not e.get("is_being_roosted") and not e.get("has_hatched"):
			return e
	return null

func _fill_hunger_and_check_egg() -> void:
	data.current_hunger = data.max_hunger
	data.happiness = clamp(data.happiness + 15.0, 0.0, 100.0)
	
	if data.happiness > 75.0 and randf() > 0.7 and egg_scene:
		print(data.species_name, " laid an egg!")
		var new_egg = egg_scene.instantiate()
		new_egg.egg_tier = data.rarity
		get_tree().current_scene.add_child(new_egg)
		new_egg.global_position = global_position

func _check_evolution() -> void:
	var threshold = 60.0 * data.evolution_tier 
	if data.accumulated_rest_time >= threshold and data.evolution_tier < 4:
		print(data.species_name, " is Evolving!!")
		data.evolution_tier += 1
		data.accumulated_rest_time = 0.0
