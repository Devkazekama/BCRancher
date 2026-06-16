extends PickableItem
class_name CornItem

func _ready() -> void:
	z_index = 1
	super._ready()
	
	# Ensure the vacuum recognizes it as food
	add_to_group("food")
	
