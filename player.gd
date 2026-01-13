extends CharacterBody2D

@export var move_speed: float = 300.0
@export var projectile_scene: PackedScene

@onready var camera = $Camera2D  # Reference to camera

var can_shoot: bool = true
var shoot_cooldown: float = 0.2  # Time between shots in seconds

func _physics_process(delta):
	# Movement
	var input_dir = Vector2.ZERO
	
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_dir.y += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_dir.y -= 1
	
	input_dir = input_dir.normalized()
	velocity = input_dir * move_speed
	move_and_slide()

func _input(event):
	# Shoot on left mouse button click (not hold)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and can_shoot:
			shoot()

func shoot():
	if not projectile_scene:
		print("ERROR: Projectile scene not assigned!")
		return
	
	if not can_shoot:
		return
	
	# Prevent rapid firing
	can_shoot = false
	await get_tree().create_timer(shoot_cooldown).timeout
	can_shoot = true
	
	# Create projectile
	var projectile = projectile_scene.instantiate()
	
	# Calculate direction from player to mouse cursor
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - global_position).normalized()
	
	# Set projectile properties
	projectile.direction = direction
	projectile.rotation = direction.angle()
	projectile.global_position = global_position
	projectile.shooter = self  # Tell bullet who shot it
	
	# Add to scene root (not parent, to avoid camera issues)
	get_tree().root.add_child(projectile)
	
	print("Bullet fired toward: ", mouse_pos)
	
	# Camera shake on shoot (optional)
	if camera and camera.has_method("apply_shake"):
		camera.apply_shake(3.0)
