extends Camera2D

# Camera smoothing settings
@export var follow_speed: float = 8.0  # Higher = snappier camera
@export var look_ahead_distance: float = 170.0  # How far ahead to look toward mouse
@export var look_ahead_smoothing: float = 3.0  # How smooth the look-ahead is

# Optional: Camera shake
@export var shake_enabled: bool = false
var shake_amount: float = 0.0
var shake_decay: float = 5.0

@onready var player = get_parent()

func _ready():
	# Make this camera the active one
	make_current()

func _process(delta):
	if not player:
		return
	
	# Calculate target position
	var target_pos = player.global_position
	
	# Add look-ahead toward mouse cursor
	if look_ahead_distance > 0:
		var mouse_pos = get_global_mouse_position()
		var direction_to_mouse = (mouse_pos - player.global_position).normalized()
		var look_ahead = direction_to_mouse * look_ahead_distance
		target_pos += look_ahead * delta * look_ahead_smoothing
	
	# Smooth camera movement (inertia)
	global_position = global_position.lerp(target_pos, follow_speed * delta)
	
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
