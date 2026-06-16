extends PickableItem
class_name Feeder

var food_stock: int = 0
@onready var drop_zone: Area2D = $DropZone

# We ONLY need to export this to toggle its visibility
@export var feed_overlay: Sprite2D

func _ready() -> void:
	z_index = 0
	super._ready() # <--- This automatically triggers the universal scaler now!
	add_to_group("feeder")
	_update_visuals()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	# The Vacuum Logic
	if drop_zone:
		for body in drop_zone.get_overlapping_bodies():
			if body.is_in_group("food") and not body.is_queued_for_deletion():
				
				# CRITICAL FIX: Only vacuum the food if it is NOT attached to a plant.
				# Using .get() is safe because if the property doesn't exist, it returns null instead of crashing.
				if body.get("is_attached") == false:
					add_food(1)
					body.queue_free()

# ---------------------------------------------------------
# FEEDER DATA & VISUAL LOGIC
# ---------------------------------------------------------

func add_food(amount: int) -> void:
	food_stock += amount
	print("Feeder stocked! Current feed: ", food_stock)
	_update_visuals()

func consume_food() -> bool:
	if food_stock > 0:
		food_stock -= 1
		print("Food consumed. Remaining feed: ", food_stock)
		_update_visuals()
		return true
	return false

func _update_visuals() -> void:
	if feed_overlay:
		feed_overlay.visible = (food_stock > 0)
