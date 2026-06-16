extends Node

# The file path where our Resource data will be stored locally on the OS.
const SAVE_PATH = "user://ranch_save_data.tres"

## Saves the CreatureData resource to the disk.
func save_game(creature_data: CreatureData) -> void:
	creature_data.last_saved_timestamp = Time.get_unix_time_from_system()
	
	var error = ResourceSaver.save(creature_data, SAVE_PATH)
	if error == OK:
		print("Game saved successfully at: ", creature_data.last_saved_timestamp)
	else:
		printerr("Failed to save game. Error code: ", error)

## Loads the Resource file from the disk, calculates AFK time, and applies it to a CreatureData resource.
func load_game(creature_data: CreatureData) -> bool:
	# 1. Check if the file actually exists on the OS before trying to load
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file found. Starting a new ranch.")
		return false
		
	# 2. Load the resource
	var loaded_data = ResourceLoader.load(SAVE_PATH) as CreatureData
	
	if loaded_data:
		# 3. Apply the loaded values back to our CreatureData resource
		creature_data.species_name = loaded_data.species_name
		creature_data.rarity = loaded_data.rarity
		creature_data.evolution_tier = loaded_data.evolution_tier
		creature_data.happiness = loaded_data.happiness
		creature_data.current_hunger = loaded_data.current_hunger
		creature_data.current_energy = loaded_data.current_energy
		creature_data.accumulated_rest_time = loaded_data.accumulated_rest_time
		
		# 4. Calculate AFK Time (How long the game was closed)
		var last_saved: float = loaded_data.last_saved_timestamp
		var current_time: float = Time.get_unix_time_from_system()

		# Prevent negative time if clock gets messed up
		if last_saved == 0.0:
			last_saved = current_time

		var seconds_away: float = max(0.0, current_time - last_saved)
		
		print("Game loaded successfully. You were away for ", seconds_away, " seconds.")
		
		# Here we can apply AFK logic (e.g., draining hunger while away)
		_apply_afk_progress(creature_data, seconds_away)
		
		return true
	else:
		printerr("Failed to load game resource.")
		return false

## Simulates the passage of time on the creature's stats while the game was closed.
func _apply_afk_progress(data: CreatureData, seconds_away: float) -> void:
	# Drain hunger based on the creature's decay rate over the time away
	data.current_hunger -= data.hunger_decay_rate * seconds_away
	data.current_hunger = clamp(data.current_hunger, 0.0, data.max_hunger)
	
	# If the creature was sleeping when the game closed, we could add energy here!
	# For now, we will just passively drain energy while awake.
	data.current_energy -= 1.0 * seconds_away
	data.current_energy = clamp(data.current_energy, 0.0, data.max_energy)
