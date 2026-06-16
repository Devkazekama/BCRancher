extends RigidBody2D
class_name PickableItem

@export_category("Physics Settings")
@export var can_rotate_and_bounce: bool = true
@export var auto_rights_itself: bool = false
@export var righting_delay: float = 1.0

@export_group("Motion Blur & VFX")
@export var use_motion_blur: bool = true
@export var min_speed: float = 1800.0
@export var stop_speed: float = 800.0
@export var spawn_distance: float = 40.0
@export var trail_lifetime: float = 0.12
@export var start_opacity: float = 0.15
@export var max_shader_pull: float = 0.08
## Drag the object's visual Sprite2D here if the ghosts aren't appearing automatically!
@export var custom_sprite_node: Node2D 

var is_grabbed: bool = false
var is_hovered: bool = false
var is_attached: bool = false
var time_resting: float = 0.0
var grab_tween: Tween

# Throwing & Offset variables
var drag_offset: Vector2 = Vector2.ZERO
var last_mouse_pos: Vector2 = Vector2.ZERO
var throw_velocity: Vector2 = Vector2.ZERO
var velocity_history: Array[Vector2] = []

# VFX Variables
var last_pos: Vector2
var distance_accumulated: float = 0.0
var is_trailing: bool = false
var active_ghosts: Array[Sprite2D] = []
var sprite_node: Node2D = null
var frames_alive: int = 0
var base_z_index: int = 0

func _ready() -> void:
	lock_rotation = !can_rotate_and_bounce
	last_pos = global_position
	base_z_index = z_index
	add_to_group("pickable")
	
	# Enable overlap tracking for the multi-grab fix
	input_pickable = true
	mouse_entered.connect(func(): is_hovered = true)
	mouse_exited.connect(func(): is_hovered = false)
	
	if custom_sprite_node:
		sprite_node = custom_sprite_node
	elif has_node("AnimatedSprite2D"): sprite_node = $AnimatedSprite2D
	elif has_node("Sprite2D"): sprite_node = $Sprite2D
	elif has_node("BodySprite"): sprite_node = $BodySprite

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if is_hovered and not is_grabbed:
				# RESTORED: Your original logic to prevent picking up multiple overlapping objects
				var highest_z = -999
				var winner = null
				
				for item in get_tree().get_nodes_in_group("pickable"):
					if is_instance_valid(item) and item.is_hovered:
						if item.base_z_index >= highest_z:
							highest_z = item.base_z_index
							winner = item
							
				if winner == self:
					_on_picked_up()
		else:
			if is_grabbed:
				_on_dropped()

func _physics_process(delta: float) -> void:
	if is_grabbed:
		var current_mouse_pos = get_global_mouse_position()
		var viewport_size = get_viewport_rect().size
		var safe_x = clamp(current_mouse_pos.x, 20.0, viewport_size.x - 20.0)
		var safe_y = clamp(current_mouse_pos.y, 20.0, viewport_size.y - 20.0)
		
		# Keep the exact grab offset so it doesn't snap to the center
		global_position = Vector2(safe_x, safe_y) + drag_offset
		
		var instant_vel = (current_mouse_pos - last_mouse_pos) / delta
		velocity_history.append(instant_vel)
		if velocity_history.size() > 5:
			velocity_history.pop_front()
			
		throw_velocity = instant_vel
		last_mouse_pos = current_mouse_pos
		
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
	else:
		if auto_rights_itself and can_rotate_and_bounce:
			if linear_velocity.length() < 15.0 and abs(angular_velocity) < 0.5:
				time_resting += delta
				if time_resting >= righting_delay and abs(rotation) > 0.05:
					_smooth_right_itself()
			else:
				time_resting = 0.0

	if use_motion_blur:
		_handle_motion_blur(delta)
	else:
		last_pos = global_position

func _on_picked_up() -> void:
	is_grabbed = true
	is_attached = false 
	z_index = 100
	
	freeze = true 
	time_resting = 0.0
	last_mouse_pos = get_global_mouse_position()
	drag_offset = global_position - last_mouse_pos # Calculate where on the sprite we grabbed
	velocity_history.clear()
	
	if grab_tween and grab_tween.is_valid():
		grab_tween.kill()
	grab_tween = create_tween()
	grab_tween.tween_property(self, "rotation", 0.0, 0.25).set_trans(Tween.TRANS_SPRING)

func _on_dropped() -> void:
	is_grabbed = false
	freeze = false 
	z_index = base_z_index
	
	if grab_tween and grab_tween.is_valid():
		grab_tween.kill()
	
	var avg_vel = Vector2.ZERO
	for v in velocity_history:
		avg_vel += v
	if velocity_history.size() > 0:
		avg_vel /= velocity_history.size()
	
	linear_velocity = avg_vel
	
	# Drastically reduced the initial throw spin. 
	# The bouncing against walls will cause the majority of the natural spin!
	if can_rotate_and_bounce:
		angular_velocity = clamp(avg_vel.x * 0.001, -5.0, 5.0)
		
	velocity_history.clear()

func _smooth_right_itself() -> void:
	time_resting = -999.0 
	var righting_tween = create_tween()
	righting_tween.tween_property(self, "rotation", 0.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	righting_tween.finished.connect(func(): time_resting = 0.0)

# --- RESTORED VFX LOGIC ---
func _handle_motion_blur(delta: float) -> void:
	active_ghosts = active_ghosts.filter(func(g): return is_instance_valid(g) and not g.is_queued_for_deletion())

	frames_alive += 1
	if frames_alive <= 3:
		last_pos = global_position
		return
		
	var distance_moved = last_pos.distance_to(global_position)
	
	if distance_moved > 2000.0:
		last_pos = global_position
		distance_accumulated = 0.0
		if sprite_node and sprite_node.material is ShaderMaterial:
			sprite_node.material.set_shader_parameter("blur_velocity", Vector2.ZERO)
		return
		
	var current_speed = 0.0
	if delta > 0:
		current_speed = distance_moved / delta
		
	if current_speed >= min_speed:
		is_trailing = true
	elif current_speed <= stop_speed:
		is_trailing = false
		distance_accumulated = 0.0
		
	if is_trailing and distance_moved > 0.001 and sprite_node:
		var direction = (global_position - last_pos).normalized()
		
		if sprite_node.material is ShaderMaterial:
			var pull_strength = min(current_speed * 0.00003, max_shader_pull)
			sprite_node.material.set_shader_parameter("blur_velocity", direction * pull_strength)
			
		var distance_to_next_spawn = spawn_distance - distance_accumulated
		var distance_traversed = 0.0
		var spawn_count = 0
		
		while distance_to_next_spawn <= (distance_moved - distance_traversed) and spawn_count < 25:
			distance_traversed += distance_to_next_spawn
			_spawn_ghost(last_pos + (direction * distance_traversed))
			distance_accumulated = 0.0
			distance_to_next_spawn = spawn_distance
			spawn_count += 1
			
		if spawn_count >= 25:
			distance_accumulated = 0.0
		else:
			distance_accumulated += (distance_moved - distance_traversed)
	else:
		if sprite_node and sprite_node.material is ShaderMaterial:
			sprite_node.material.set_shader_parameter("blur_velocity", Vector2.ZERO)
			
	last_pos = global_position

func _spawn_ghost(spawn_pos: Vector2) -> void:
	if sprite_node == null: return
	
	var ghost = Sprite2D.new()
	if sprite_node is AnimatedSprite2D: 
		ghost.texture = sprite_node.sprite_frames.get_frame_texture(sprite_node.animation, sprite_node.frame)
	elif sprite_node is Sprite2D: 
		ghost.texture = sprite_node.texture

	# Ensure ghosts correctly track local offsets and rotation!
	var rotated_offset = sprite_node.position.rotated(sprite_node.global_rotation)
	ghost.global_position = spawn_pos + rotated_offset
	ghost.rotation = sprite_node.global_rotation 
	ghost.scale = sprite_node.global_scale
	if "flip_h" in sprite_node: ghost.flip_h = sprite_node.flip_h
	
	ghost.z_as_relative = false
	ghost.z_index = base_z_index - 1
	ghost.top_level = true
	ghost.modulate = Color(1.0, 1.0, 1.0, start_opacity)
	
	get_parent().add_child(ghost)
	active_ghosts.append(ghost)
	
	var tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, trail_lifetime).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(ghost.queue_free)
