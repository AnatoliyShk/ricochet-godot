extends StaticBody2D

@export var rotation_speed: float = 10.0  # How fast it rotates (radians per second)
@export var shake_on_impact: bool = true
@export var shake_intensity: float = 3.0

enum WallState { HORIZONTAL, VERTICAL, ROTATING }

var current_state: WallState = WallState.HORIZONTAL
var target_rotation: float = 0.0
var is_rotating: bool = false
var original_position: Vector2
var shake_timer: float = 0.0

func _ready():
	add_to_group("walls")
	original_position = global_position
	
	# Set initial rotation based on current rotation
	if abs(rotation_degrees) < 45 or abs(rotation_degrees) > 135:
		current_state = WallState.HORIZONTAL
		target_rotation = 0.0
	else:
		current_state = WallState.VERTICAL
		target_rotation = PI / 2
	
	rotation = target_rotation

func _physics_process(delta):
	# Handle rotation
	if is_rotating:
		# Smoothly rotate towards target
		var diff = target_rotation - rotation
		
		# Normalize angle difference
		while diff > PI:
			diff -= TAU
		while diff < -PI:
			diff += TAU
		
		if abs(diff) > 0.01:
			rotation += sign(diff) * min(abs(diff), rotation_speed * delta)
		else:
			# Rotation complete
			rotation = target_rotation
			is_rotating = false
			update_state()
	
	# Handle shake
	if shake_timer > 0:
		shake_timer -= delta
		if shake_timer > 0:
			var shake_offset = Vector2(
				randf_range(-shake_intensity, shake_intensity),
				randf_range(-shake_intensity, shake_intensity)
			)
			global_position = original_position + shake_offset
		else:
			global_position = original_position

func on_bullet_impact(impact_position: Vector2):
	print("Rotating wall hit! Current state: ", current_state)
	
	# Start shake
	if shake_on_impact:
		shake_timer = 0.2
		original_position = global_position
	
	# Start rotation if not already rotating
	if not is_rotating:
		flip_rotation()

func flip_rotation():
	is_rotating = true
	
	# Toggle between horizontal and vertical
	if current_state == WallState.HORIZONTAL:
		# Flip to vertical
		target_rotation = rotation + PI / 2
		print("Rotating to VERTICAL")
	else:
		# Flip to horizontal
		target_rotation = rotation + PI / 2
		print("Rotating to HORIZONTAL")

func update_state():
	# Update state after rotation completes
	# Normalize rotation to 0-2PI range
	var normalized_rot = fmod(rotation, TAU)
	if normalized_rot < 0:
		normalized_rot += TAU
	
	# Determine state based on rotation
	if (normalized_rot < PI / 4) or (normalized_rot > 7 * PI / 4):
		current_state = WallState.HORIZONTAL
	elif (normalized_rot > PI / 4) and (normalized_rot < 3 * PI / 4):
		current_state = WallState.VERTICAL
	elif (normalized_rot > 3 * PI / 4) and (normalized_rot < 5 * PI / 4):
		current_state = WallState.HORIZONTAL
	else:
		current_state = WallState.VERTICAL
	
	print("Rotation complete! New state: ", current_state)
