extends Node2D

@export var max_distance: float = 2000.0  # How far the ray traces
@export var max_ricochets: int = 3  # Match your projectile's max ricochets
@export var laser_color: Color = Color.RED
@export var laser_width: float = 2.0
@export var ricochet_point_size: float = 5.0
@export var ray_step_size: float = 10.0  # Smaller = more accurate but slower

var line: Line2D

func _ready():
	# Create the laser line
	line = Line2D.new()
	line.width = laser_width
	line.default_color = laser_color
	add_child(line)

func _process(_delta):
	update_trajectory()

func update_trajectory():
	line.clear_points()
	
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
	line.add_point(to_local(current_pos))
	
	while ricochets_done <= max_ricochets:
		# Raycast in current direction
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(current_pos, current_pos + current_dir * max_distance)
		query.exclude = [player]  # Don't hit the player
		query.collide_with_areas = false  # Ignore Area2D (like the player's detection areas)
		query.collide_with_bodies = true  # Only hit bodies (walls, enemies)
		
		var result = space_state.intersect_ray(query)
		
		if result:
			# Hit something - add the hit point
			line.add_point(to_local(result.position))
			
			# Check if we should ricochet
			if ricochets_done < max_ricochets:
				var hit_body = result.collider
				
				# Check if it's a wall (match projectile logic exactly)
				if hit_body.is_in_group("walls") or hit_body is StaticBody2D or hit_body is TileMap:
					# Calculate 90-degree ricochet (EXACTLY like projectile)
					var normal = result.normal
					
					# Same logic as projectile
					if abs(normal.x) > abs(normal.y):
						# Vertical wall - flip X
						current_dir.x = -current_dir.x
					else:
						# Horizontal wall - flip Y
						current_dir.y = -current_dir.y
					
					# Start next ray from hit point (offset to avoid re-hitting)
					current_pos = result.position + current_dir * 5
					ricochets_done += 1
				else:
					# Hit enemy or non-wall, stop here
					break
			else:
				# Max ricochets reached
				break
		else:
			# No hit - extend to max distance
			line.add_point(to_local(current_pos + current_dir * max_distance))
			break

# Function to get trajectory data (for debugging or other uses)
func get_trajectory_points() -> Array:
	var points = []
	for i in line.get_point_count():
		points.append(line.get_point_position(i))
	return points
