extends StaticBody2D

@export var shake_intensity: float = 5.0  # How much the wall shakes
@export var shake_duration: float = 0.3   # How long the shake lasts
@export var shake_frequency: float = 30.0 # How fast it shakes

var original_position: Vector2
var is_shaking: bool = false
var shake_timer: float = 0.0

@onready var collision_shape = $CollisionShape2D if has_node("CollisionShape2D") else null

func _ready():
	# Store the GLOBAL position, not local
	original_position = global_position
	add_to_group("walls")

	# Auto-create NavigationObstacle2D for pathfinding
	setup_navigation_obstacle()

func setup_navigation_obstacle():
	# Check if we already have a navigation obstacle
	if has_node("NavigationObstacle2D"):
		return
	
	# Create navigation obstacle automatically
	var obstacle = NavigationObstacle2D.new()
	obstacle.name = "NavigationObstacle2D"
	obstacle.avoidance_enabled = true
	
	# Try to match obstacle size to collision shape
	if collision_shape and collision_shape.shape:
		var shape = collision_shape.shape
		if shape is RectangleShape2D:
			obstacle.radius = shape.size.length() / 2.0
			print("Navigation obstacle created - Radius: ", obstacle.radius)
		elif shape is CircleShape2D:
			obstacle.radius = shape.radius
			print("Navigation obstacle created - Radius: ", obstacle.radius)
		else:
			obstacle.radius = 32  # Default
	else:
		obstacle.radius = 32  # Default
	
	add_child(obstacle)

func _process(delta):
	if is_shaking:
		shake_timer -= delta
		
		if shake_timer > 0:
			# Random shake offset
			var shake_offset = Vector2(
				randf_range(-shake_intensity, shake_intensity),
				randf_range(-shake_intensity, shake_intensity)
			)
			global_position = original_position + shake_offset
		else:
			# Shake finished - return to original position
			is_shaking = false
			global_position = original_position
			print("Wall returned to: ", global_position)

func on_bullet_impact(impact_position: Vector2):
	# Called when a bullet hits this wall
	print("Wall hit! Starting shake")
	start_shake()

func start_shake():
	# Always update original position before shaking
	if not is_shaking:
		original_position = global_position
	is_shaking = true
	shake_timer = shake_duration
