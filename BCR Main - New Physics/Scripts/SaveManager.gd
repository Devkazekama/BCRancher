extends Node

# The file path where our JSON data will be stored locally on the OS.
const SAVE_PATH = "user://ranch_save_data.json"

## Serializes the CreatureData resource into a JSON string and saves it to the disk.
func save_game(creature_data: CreatureData) -> void:
	# 1. Create a Dictionary containing all the variables from CreatureData
	# We also inject the current Unix timestamp so we can calculate AFK time later.
	var save_dict: Dictionary = {
		"last_saved_timestamp": Time.get_unix_time_from_system(),
		"species_name": creature_data.species_name,
		"rarity": creature_data.rarity,
		"evolution_tier": creature_data.evolution_tier,
		"happiness": creature_data.happiness,
		"current_hunger": creature_data.current_hunger,
		"current_energy": creature_data.current_energy,
		"accumulated_rest_time": creature_data.accumulated_rest_time
	}
	
	# 2. Convert the Dictionary to a JSON string
	var json_string: String = JSON.stringify(save_dict, "\t")
	
	# 3. Open the file securely and write the string to the OS
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("Game saved successfully at: ", Time.get_unix_time_from_system())
	else:
		printerr("Failed to open save file for writing.")

## Loads the JSON file from the disk, calculates AFK time, and applies it to a CreatureData resource.
func load_game(creature_data: CreatureData) -> bool:
	# 1. Check if the file actually exists on the OS before trying to load
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file found. Starting a new ranch.")
		return false
		
	# 2. Open the file and read the JSON string
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	# 3. Parse the JSON string back into a Godot Dictionary
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error == OK:
		var save_dict: Dictionary = json.data
		
		# 4. Apply the loaded values back to our CreatureData resource
		creature_data.species_name = save_dict.get("species_name", "Apprentice Chick")
		creature_data.rarity = save_dict.get("rarity", 1)
		creature_data.evolution_tier = save_dict.get("evolution_tier", 1)
		creature_data.happiness = save_dict.get("happiness", 50.0)
		creature_data.current_hunger = save_dict.get("current_hunger", 100.0)
		creature_data.current_energy = save_dict.get("current_energy", 50.0)
		creature_data.accumulated_rest_time = save_dict.get("accumulated_rest_time", 0.0)
		
		# 5. Calculate AFK Time (How long the game was closed)
		var last_saved: float = save_dict.get("last_saved_timestamp", Time.get_unix_time_from_system())
		var current_time: float = Time.get_unix_time_from_system()
		var seconds_away: float = current_time - last_saved
		
		print("Game loaded successfully. You were away for ", seconds_away, " seconds.")
		
		# Here we can apply AFK logic (e.g., draining hunger while away)
		_apply_afk_progress(creature_data, seconds_away)
		
		return true
	else:
		printerr("JSON Parse Error: ", json.get_error_message())
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
