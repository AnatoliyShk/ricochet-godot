
extends StaticBody2D

@export var shake_intensity: float = 5.0  # How much the wall shakes
@export var shake_duration: float = 0.3   # How long the shake lasts
@export var shake_frequency: float = 30.0 # How fast it shakes

var original_position: Vector2
var is_shaking: bool = false
var shake_timer: float = 0.0

func _ready():
	# Store the GLOBAL position, not local
	original_position = global_position
	# Make sure wall is in the "walls" group for ricochets
	add_to_group("walls")
	print("Wall initialized at: ", original_position)

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
