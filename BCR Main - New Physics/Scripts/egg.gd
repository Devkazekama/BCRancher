extends Node2D
class_name Egg

@export var egg_tier: int = 1
var hatch_progress: float = 0.0
var required_hatch_time: float = 60.0 # Base seconds to hatch
var is_being_roosted: bool = false
var has_hatched: bool = false

func _ready() -> void:
	add_to_group("egg")
	# Higher tier eggs take longer to hatch
	required_hatch_time = 60.0 * egg_tier

func _process(delta: float) -> void:
	if has_hatched:
		return
		
	# Progress only happens when a chicken is roosting on it
	if is_being_roosted:
		hatch_progress += delta
		if hatch_progress >= required_hatch_time:
			hatch()

func hatch() -> void:
	has_hatched = true
	print("An egg of tier ", egg_tier, " has hatched!")
	# TODO: Instantiate a new Tier 1 Creature here
	queue_free()
