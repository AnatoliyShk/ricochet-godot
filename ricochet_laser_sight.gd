extends Node2D

@export var max_distance: float = 2000.0
@export var max_ricochets: int = 3
@export var arrow_color: Color = Color(1, 0.3, 0.3, 0.8)  # Red with transparency
@export var arrow_size: float = 15.0
@export var arrow_spacing: float = 50.0  # Distance between arrows
@export var arrow_speed: float = 300.0  # How fast arrows move along path
@export var show_trajectory: bool = true
@export var num_flowing_arrows: int = 20  # How many arrows flow at once

var trajectory_points: Array = []
var arrow_offsets: Array = []  # Offset along path for each arrow (0 to 1)
var total_path_length: float = 0.0

func _ready():
	# Initialize arrows with even distribution
	arrow_offsets.clear()
	for i in range(num_flowing_arrows):
		arrow_offsets.append(float(i) / num_flowing_arrows)

func _process(delta):
	# Only show trajectory when right mouse button is held
	var show = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not Input.is_key_pressed(KEY_CTRL)
	
	if show and show_trajectory:
		update_trajectory()
		update_arrow_positions(delta)
		queue_redraw()
	else:
		# Clear when not showing
		trajectory_points.clear()
		queue_redraw()

func update_trajectory():
	trajectory_points.clear()
	total_path_length = 0.0
	
	var player = get_parent()
	if not player:
		return
	
	# Get shooting direction (toward mouse)
	var start_pos = player.global_position
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - start_pos).normalized()
	
	# Trace ricochets
	var current_pos = start_pos
	var current_dir = direction
	var ricochets_done = 0
	
	# Add starting point
	trajectory_points.append(to_local(current_pos))
	
	while ricochets_done <= max_ricochets:
		# Raycast in current direction
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(current_pos, current_pos + current_dir * max_distance)
		query.exclude = [player]
		query.collide_with_areas = false
		query.collide_with_bodies = true
		
		var result = space_state.intersect_ray(query)
		
		if result:
			# Hit something - add the hit point
			var hit_point = to_local(result.position)
			trajectory_points.append(hit_point)
			
			# Calculate path length for this segment
			if trajectory_points.size() > 1:
				var prev_point = trajectory_points[trajectory_points.size() - 2]
				total_path_length += prev_point.distance_to(hit_point)
			
			# Check if we should ricochet
			if ricochets_done < max_ricochets:
				var hit_body = result.collider
				
				# Check if it's a wall
				if hit_body.is_in_group("walls") or hit_body is StaticBody2D or hit_body is TileMap:
					var normal = result.normal
					
					# 90-degree ricochet
					if abs(normal.x) > abs(normal.y):
						current_dir.x = -current_dir.x
					else:
						current_dir.y = -current_dir.y
					
					# Start next ray from hit point
					current_pos = result.position + current_dir * 5
					ricochets_done += 1
				else:
					# Hit non-wall, stop
					break
			else:
				# Max ricochets reached
				break
		else:
			# No hit - extend to max distance
			var end_point = to_local(current_pos + current_dir * max_distance)
			trajectory_points.append(end_point)
			if trajectory_points.size() > 1:
				var prev_point = trajectory_points[trajectory_points.size() - 2]
				total_path_length += prev_point.distance_to(end_point)
			break
	
	# Reinitialize arrow offsets if needed
	if arrow_offsets.size() == 0:
		for i in range(num_flowing_arrows):
			arrow_offsets.append(float(i) / num_flowing_arrows)

func update_arrow_positions(delta):
	if total_path_length <= 0:
		return
	
	# Move each arrow along the path as a percentage (0 to 1)
	var speed_ratio = arrow_speed / total_path_length
	
	for i in range(arrow_offsets.size()):
		arrow_offsets[i] += speed_ratio * delta
		
		# Loop back to start when reaching end
		while arrow_offsets[i] >= 1.0:
			arrow_offsets[i] -= 1.0

func _draw():
	if not show_trajectory or trajectory_points.size() < 2:
		return
	
	# Draw arrows along the trajectory
	for offset in arrow_offsets:
		var distance = offset * total_path_length
		var arrow_data = get_point_on_path(distance)
		if arrow_data:
			draw_arrow(arrow_data.position, arrow_data.direction)

func get_point_on_path(distance: float) -> Dictionary:
	if trajectory_points.size() < 2:
		return {}
	
	var accumulated_dist = 0.0
	
	for i in range(trajectory_points.size() - 1):
		var start = trajectory_points[i]
		var end = trajectory_points[i + 1]
		var segment_length = start.distance_to(end)
		
		if accumulated_dist + segment_length >= distance:
			# The point is in this segment
			var segment_progress = (distance - accumulated_dist) / segment_length
			var position = start.lerp(end, segment_progress)
			var direction = (end - start).normalized()
			return {"position": position, "direction": direction}
		
		accumulated_dist += segment_length
	
	return {}

func draw_arrow(pos: Vector2, dir: Vector2):
	# Arrow is a triangle pointing in the direction of travel
	var angle = dir.angle()
	
	# Arrow points
	var tip = pos + dir * arrow_size
	var left = pos + Vector2(-arrow_size * 0.5, -arrow_size * 0.5).rotated(angle)
	var right = pos + Vector2(-arrow_size * 0.5, arrow_size * 0.5).rotated(angle)
	
	var arrow_points = PackedVector2Array([tip, left, right])
	draw_colored_polygon(arrow_points, arrow_color)
	
	# Optional: Add outline
	draw_polyline(PackedVector2Array([tip, left, right, tip]), Color.WHITE, 1.0)
