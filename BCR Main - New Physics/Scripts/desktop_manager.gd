extends Node
class_name DesktopManager

@export var entity_container: Node2D

func _ready() -> void:
	get_viewport().transparent_bg = true
	Input.set_use_accumulated_input(false)
	call_deferred("_setup_window")

func _setup_window() -> void:
	var main_window: Window = get_window()
	main_window.borderless = true
	main_window.always_on_top = true
	main_window.transparent = true
	
	var screen_rect = DisplayServer.screen_get_usable_rect(main_window.current_screen)
	main_window.position = screen_rect.position
	
	# The 15px invisible gutter to safely catch interpolation bounces
	main_window.size = Vector2(screen_rect.size.x, screen_rect.size.y + 15)

	if entity_container:
		entity_container.position = Vector2.ZERO

func _process(_delta: float) -> void:
	_update_passthrough_region()

func _update_passthrough_region() -> void:
	var polygons: Array[PackedVector2Array] = []
	var is_anything_grabbed = false
	
	for child in entity_container.get_children():
		if not is_instance_valid(child) or child.is_queued_for_deletion():
			continue
			
		# FIX 1: If ANY item is currently grabbed, take over the whole screen!
		if "is_grabbed" in child and child.get("is_grabbed") == true:
			is_anything_grabbed = true
			break
			
		if child.is_visible_in_tree() and child is Node2D:
			var poly = _get_node_polygon(child)
			if poly.size() > 0:
				polygons.append(poly)

	# Apply the Fullscreen override if dragging
	if is_anything_grabbed:
		# Passing an empty array disables passthrough, claiming the whole window
		DisplayServer.window_set_mouse_passthrough(PackedVector2Array())
		return

	if polygons.size() == 0:
		DisplayServer.window_set_mouse_passthrough([Vector2(-1, -1)])
		return

	var islands = polygons.duplicate()
	var merging = true
	while merging:
		merging = false
		for i in range(islands.size()):
			for j in range(i + 1, islands.size()):
				var result = Geometry2D.merge_polygons(islands[i], islands[j])
				if result.size() == 1:
					islands[i] = result[0]
					islands.remove_at(j)
					merging = true
					break
			if merging:
				break

	var sorted_islands = []
	for island in islands:
		# FIX 2: Find the absolute top-left-most point of the shape to drop the line to.
		# This prevents the drop-lines from crossing over each other and causing the black line!
		var best_point = island[0]
		var best_index = 0
		for i in range(1, island.size()):
			if island[i].x < best_point.x or (island[i].x == best_point.x and island[i].y < best_point.y):
				best_point = island[i]
				best_index = i
		sorted_islands.append({
			"poly": island,
			"point": best_point,
			"index": best_index
		})
		
	sorted_islands.sort_custom(func(a, b): return a.point.x < b.point.x)

	var master_poly = PackedVector2Array()
	var win_size = get_window().size
	master_poly.append(Vector2(1, -1)) 

	for data in sorted_islands:
		var island = data.poly
		var best_point = data.point
		var best_index = data.index

		master_poly.append(Vector2(best_point.x, -1))
		master_poly.append(best_point)

		for i in range(island.size() + 1):
			var idx = (best_index + i) % island.size()
			master_poly.append(island[idx])
			
		master_poly.append(Vector2(best_point.x + 0.1, -1))

	master_poly.append(Vector2(win_size.x - 1, -1)) 
	DisplayServer.window_set_mouse_passthrough(master_poly)


func _get_node_polygon(node: Node2D) -> PackedVector2Array:
	var points_to_hull = PackedVector2Array()

	# STEP 1: Gather the Rotated Collision Points
	var col_shape: CollisionShape2D = node.get_node_or_null("CollisionShape2D")
	var poly_node: CollisionPolygon2D = node.get_node_or_null("CollisionPolygon2D")
	
	if poly_node and poly_node.polygon.size() > 0:
		var transform_matrix = poly_node.global_transform
		for p in poly_node.polygon:
			points_to_hull.append(transform_matrix * p)
			
	elif col_shape and col_shape.shape:
		var transform_matrix = col_shape.global_transform
		if col_shape.shape is RectangleShape2D:
			var size = col_shape.shape.size / 2.0
			points_to_hull.append(transform_matrix * Vector2(-size.x, -size.y))
			points_to_hull.append(transform_matrix * Vector2(size.x, -size.y))
			points_to_hull.append(transform_matrix * Vector2(size.x, size.y))
			points_to_hull.append(transform_matrix * Vector2(-size.x, size.y))
			
		elif col_shape.shape is CircleShape2D or col_shape.shape is CapsuleShape2D:
			var radius = col_shape.shape.radius
			for i in range(8): 
				var angle = (i / 8.0) * TAU
				var point = Vector2(cos(angle), sin(angle)) * radius
				if col_shape.shape is CapsuleShape2D:
					point.y += ((col_shape.shape.height / 2.0) - radius) * sign(point.y)
				points_to_hull.append(transform_matrix * point)

	# STEP 2: Gather Visual Sprite Points (The Feeder Fix)
	# This ensures artwork that extends beyond the collision box is protected
	for child in node.get_children():
		if child is Sprite2D and child.texture:
			var rect = child.get_rect()
			var t = child.global_transform
			points_to_hull.append(t * rect.position)
			points_to_hull.append(t * Vector2(rect.end.x, rect.position.y))
			points_to_hull.append(t * rect.end)
			points_to_hull.append(t * Vector2(rect.position.x, rect.end.y))
			
		elif child is AnimatedSprite2D and child.sprite_frames:
			var anim = child.animation
			var frame = child.frame
			if child.sprite_frames.has_animation(anim):
				var tex = child.sprite_frames.get_frame_texture(anim, frame)
				if tex:
					var size = tex.get_size()
					# Approximate bounds assuming the sprite is centered
					var pos = -size / 2.0 
					var t = child.global_transform
					points_to_hull.append(t * pos)
					points_to_hull.append(t * Vector2(pos.x + size.x, pos.y))
					points_to_hull.append(t * Vector2(pos.x + size.x, pos.y + size.y))
					points_to_hull.append(t * Vector2(pos.x, pos.y + size.y))

	# If absolutely nothing was found, drop a generic box
	if points_to_hull.size() == 0:
		var transform_matrix = node.global_transform
		var size = Vector2(25, 25)
		points_to_hull.append(transform_matrix * Vector2(-size.x, -size.y))
		points_to_hull.append(transform_matrix * Vector2(size.x, -size.y))
		points_to_hull.append(transform_matrix * Vector2(size.x, size.y))
		points_to_hull.append(transform_matrix * Vector2(-size.x, size.y))

	# STEP 3: Gather OS Lag Prediction Points
	var base_points = points_to_hull.duplicate()
	var lag_vector = Vector2.ZERO
	
	if "linear_velocity" in node and node.get("linear_velocity") != Vector2.ZERO:
		lag_vector = -node.get("linear_velocity") * get_process_delta_time() * 2.5
	elif "is_grabbed" in node and node.get("is_grabbed") == true:
		if "throw_velocity" in node: # Updated variable name to match our new throw logic
			lag_vector = -node.get("throw_velocity") * get_process_delta_time() * 2.5
			
	if lag_vector != Vector2.ZERO:
		for p in base_points:
			points_to_hull.append(p + lag_vector)
			points_to_hull.append(p - lag_vector)

	# STEP 4: Gather Ghost Trail Points
	if "active_ghosts" in node:
		for ghost in node.get("active_ghosts"):
			if is_instance_valid(ghost) and not ghost.is_queued_for_deletion():
				var g_pos = ghost.global_position
				var g_size = 45.0 
				points_to_hull.append(g_pos + Vector2(-g_size, -g_size))
				points_to_hull.append(g_pos + Vector2(g_size, -g_size))
				points_to_hull.append(g_pos + Vector2(g_size, g_size))
				points_to_hull.append(g_pos + Vector2(-g_size, g_size))

	# STEP 5: Snap the Rubber Band & Expand
	var hull_poly = Geometry2D.convex_hull(points_to_hull)
	var expanded_poly = PackedVector2Array()
	var buffer_size = 20.0
	
	if "is_grabbed" in node and node.get("is_grabbed") == true:
		buffer_size = 60.0

	if hull_poly.size() > 0:
		var offset_polys = Geometry2D.offset_polygon(hull_poly, buffer_size)
		if offset_polys.size() > 0:
			expanded_poly = offset_polys[0]
			
	return expanded_poly
