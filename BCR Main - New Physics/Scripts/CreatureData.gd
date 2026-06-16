extends Resource
class_name CreatureData

@export_group("Identity")
@export var species_name: String = "Apprentice Chick"
@export var rarity: int = 1 
@export var evolution_tier: int = 1 

@export_group("Core Stats")
@export var happiness: float = 50.0
@export var current_hunger: float = 100.0
@export var current_energy: float = 50.0
@export var accumulated_rest_time: float = 0.0 

@export_group("Personality & Genetics")
## How fast happiness increases when needs are met
@export var happiness_gain_rate: float = 1.5 
## How fast happiness drops when starving or exhausted
@export var happiness_loss_rate: float = 1.5 
## Multiplier for how fast this specific creature evolves
@export var evolution_rate_modifier: float = 1.0 

@export var walk_speed: float = 100.0 

## Base rate of energy gained per second while sleeping
@export var base_rest_energy_rate: float = 10.0 
## Base rate of energy lost per second while awake
@export var base_energy_decay_rate: float = 1.0 
## Base rate of hunger lost per second
@export var base_hunger_decay_rate: float = 2.0 

@export_group("Behavior Probabilities")
## Chance (0.0 to 1.0) to start wandering from idle
@export var action_chance_wander: float = 0.3 
## Chance (0.0 to 1.0) to take a random nap from idle (if energy < 80%)
@export var action_chance_nap: float = 0.1 

# Dynamic stat limits based on tier
var max_hunger: float:
	get: return 100.0 * evolution_tier

var max_energy: float:
	get: return 100.0 * evolution_tier 

# Adjusted dynamic rates
var rest_energy_rate: float:
	get: return (base_rest_energy_rate / evolution_tier)
	
var energy_decay_rate: float:
	get: return base_energy_decay_rate
	
var hunger_decay_rate: float:
	get: return (base_hunger_decay_rate / evolution_tier)
