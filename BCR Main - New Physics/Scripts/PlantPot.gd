extends PickableItem
class_name PlantPot

@export var corn_scene: PackedScene
@export var sort_container: Node2D

@onready var timer: Timer = $Timer
@onready var spawn_point: Marker2D = $SpawnPoint

var current_corn: Node2D = null

func _ready() -> void:
	z_index = 8
	super._ready()
	
	if timer:
		if not timer.is_connected("timeout", _on_timer_timeout):
			timer.timeout.connect(_on_timer_timeout)
		timer.start()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	# Only glue the corn to the pot IF it hasn't been picked up yet
	if is_instance_valid(current_corn) and current_corn.get("is_attached") == true:
		current_corn.global_position = spawn_point.global_position
		current_corn.global_rotation = spawn_point.global_rotation
		current_corn.linear_velocity = Vector2.ZERO
		current_corn.angular_velocity = 0.0

func _on_timer_timeout() -> void:
	spawn_corn()

func spawn_corn() -> void:
	if corn_scene == null: return
	
	if is_instance_valid(current_corn) and current_corn.get("is_attached") == true: 
		return 
	
	var new_corn = corn_scene.instantiate()
	if sort_container:
		sort_container.add_child(new_corn)
	else:
		get_parent().add_child(new_corn)
		
	new_corn.global_position = spawn_point.global_position
	new_corn.global_rotation = spawn_point.global_rotation
	
	# FIX 1: Freeze the RigidBody! 
	# This forces the invisible collision shape to follow the visual sprite perfectly.
	new_corn.freeze = true 
	
	# FIX 2: Massive Z-Index Guarantee
	# We calculate this from base_z_index so it doesn't accidentally inherit 
	# the "100" z_index if you happen to be dragging the plant pot when it spawns!
	new_corn.base_z_index = self.base_z_index + 10
	new_corn.z_index = new_corn.base_z_index
	
	if "is_attached" in new_corn:
		new_corn.set("is_attached", true)
		
	current_corn = new_corn

# Add this to PlantPot.gd

func _on_picked_up() -> void:
	# 1. First, perform the standard grab logic (this sets the pot to z_index = 100)
	super._on_picked_up()
	
	# 2. Force the corn to stay ahead of the pot by an extra offset
	if is_instance_valid(current_corn):
		current_corn.z_index = self.z_index + 1
		# If the corn has a sprite, ensure it's on top of everything inside the pot
		if "sprite_node" in current_corn and current_corn.sprite_node:
			current_corn.sprite_node.z_index = 10

func _on_dropped() -> void:
	# 1. Return the pot to its base layer
	super._on_dropped()
	
	# 2. Return the corn to its standard offset
	if is_instance_valid(current_corn):
		current_corn.z_index = self.base_z_index + 1
		if "sprite_node" in current_corn and current_corn.sprite_node:
			current_corn.sprite_node.z_index = 0
