extends Camera2D

# Camera smoothing settings
@export var follow_speed: float = 8.0  # How fast camera catches up
@export var look_ahead_distance: float = 100.0  # How far ahead to look toward mouse
@export var look_ahead_smoothing: float = 5.0  # How smooth the look-ahead is
@export var max_offset: float = 150.0  # Maximum camera offset from player
@export var position_smoothing: float = 0.1  # Lower = more inertia (0.05-0.2)

# Optional: Camera shake
@export var shake_enabled: bool = false
var shake_amount: float = 0.0
var shake_decay: float = 5.0

var camera_velocity: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO

func _ready():
	# Make this camera the active one
	make_current()
	# Initialize target to current position
	if get_parent():
		target_position = get_parent().global_position

func _process(delta):
	var player = get_parent()
	if not player:
		return
	
	# Calculate desired camera position
	var desired_pos = player.global_position
	
	# Add look-ahead toward mouse cursor
	if look_ahead_distance > 0:
		var mouse_pos = get_global_mouse_position()
		var direction_to_mouse = (mouse_pos - player.global_position).normalized()
		var look_ahead = direction_to_mouse * look_ahead_distance
		
		# Clamp look-ahead to max offset
		if look_ahead.length() > max_offset:
			look_ahead = look_ahead.normalized() * max_offset
		
		desired_pos += look_ahead
	
	# Smooth the target position with inertia
	target_position = target_position.lerp(desired_pos, look_ahead_smoothing * delta)
	
	# Apply smooth camera movement with velocity-based smoothing
	var distance_to_target = target_position - global_position
	camera_velocity = camera_velocity.lerp(distance_to_target * follow_speed, position_smoothing)
	global_position += camera_velocity * delta
	
	# Apply camera shake if enabled
	if shake_enabled and shake_amount > 0:
		offset = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		shake_amount = max(0, shake_amount - shake_decay * delta)
	else:
		offset = Vector2.ZERO

# Call this function to shake the camera (e.g., when shooting)
func apply_shake(amount: float):
	shake_amount = amount
