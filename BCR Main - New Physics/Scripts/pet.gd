extends PickableItem
class_name Pet

@export_group("Data & Loadout")
@export var data: CreatureData 
@export var egg_scene: PackedScene 

@export_group("Personality & Movement")
@export var walk_speed: float = 100.0
@export var acceleration: float = 0.1

var state_timer: float = 0.0
var target_destination: Vector2 = Vector2.ZERO
var target_node: Node2D = null

var debug_timer: float = 0.0 

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine: StateMachine = $StateMachine

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
		var current_state_name = "None"
		if state_machine and state_machine.current_state:
			current_state_name = state_machine.current_state.name
		print("[%s] State: %s | Hunger: %d/%d | Energy: %d/%d | Happiness: %d | Evo: %.1f%%" % [
			data.species_name, current_state_name,
			data.current_hunger, data.max_hunger, data.current_energy, data.max_energy, data.happiness, evo_pct
		])
		
	# 2. Check the new variable name from PickableItem
	if is_grabbed:
		return
		
	_update_needs(delta)
	
	if state_machine:
		_evaluate_state_machine()
		state_machine.process_machine(delta)

	is_walking = false
	if state_machine and state_machine.current_state:
		var s_name = state_machine.current_state.name
		is_walking = (s_name == "WanderState" or s_name == "MovingToFeederState" or s_name == "MovingToEggState" or s_name == "FindingBedState")

func _on_picked_up() -> void:
	super._on_picked_up()
	if state_machine and state_machine.current_state:
		var s_name = state_machine.current_state.name
		if s_name == "SleepingState" or s_name == "FindingBedState":
			print(data.species_name, " was woken up abruptly!")
			state_machine.change_state("IdleState")

func _update_needs(delta: float) -> void:
	var energy_pct = (data.current_energy / data.max_energy) * 100.0
	var hunger_pct = (data.current_hunger / data.max_hunger) * 100.0

	var is_sleeping = false
	if state_machine and state_machine.current_state:
		is_sleeping = (state_machine.current_state.name == "SleepingState")

	if is_sleeping:
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
	
	var is_wandering = false
	if state_machine and state_machine.current_state:
		is_wandering = (state_machine.current_state.name == "WanderState")

	# Personality-driven Happiness Logic
	if hunger_pct > 70.0 and energy_pct > 70.0:
		data.happiness += data.happiness_gain_rate * delta
	elif is_wandering:
		data.happiness += (data.happiness_gain_rate * 0.5) * delta
	
	if energy_pct < 25.0 or hunger_pct < 25.0:
		data.happiness -= data.happiness_loss_rate * delta
		
	data.happiness = clamp(data.happiness, 0.0, 100.0)

func _evaluate_state_machine() -> void:
	if not state_machine or not state_machine.current_state:
		return

	var s_name = state_machine.current_state.name
	if s_name == "EatingState" or s_name == "RoostingState" or s_name == "FindingBedState":
		return
		
	var energy_pct = (data.current_energy / data.max_energy) * 100.0
	var hunger_pct = (data.current_hunger / data.max_hunger) * 100.0
	
	# 1. ALWAYS check for food if hungry, even if sleeping or exhausted
	if hunger_pct <= 25.0:
		var food_source = _find_available_food()
		if food_source:
			state_machine.change_state("MovingToFeederState", food_source)
			return
		elif s_name != "SleepingState":
			# If no food exists, and we are starving, go to sleep to conserve energy
			state_machine.change_state("FindingBedState")
			return
			
	# 2. Exhaustion logic
	if energy_pct <= 25.0 and s_name != "SleepingState":
		state_machine.change_state("FindingBedState")
		return
		
	# 3. Wake up naturally logic is handled in SleepingState.gd
		
	# 4. Roosting Logic
	if data.evolution_tier > 1 and hunger_pct > 50.0 and energy_pct > 50.0:
		if s_name != "MovingToEggState":
			var free_egg = _find_free_egg()
			if free_egg:
				state_machine.change_state("MovingToEggState", free_egg)
				return

func _play_flavor_idle() -> void:
	if not anim_sprite: return
	var flavor_anims = ["idle", "idle", "idle", "idle", "eat"]
	anim_sprite.play(flavor_anims.pick_random())

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
