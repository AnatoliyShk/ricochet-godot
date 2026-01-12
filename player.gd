extends CharacterBody2D

@export var move_speed: float = 300.0
@export var projectile_scene: PackedScene

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
	
	# Shooting - use mouse button directly
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		shoot()

func shoot():
	print("Shoot function called!")
	
	if not projectile_scene:
		print("ERROR: Projectile scene not assigned!")
		return
	
	print("Creating projectile...")
	
	# Create projectile
	var projectile = projectile_scene.instantiate()
	
	# Set position at player
	projectile.global_position = global_position
	print("Spawning at player: ", global_position)
	
	# Set direction towards mouse
	var direction = (get_global_mouse_position() - global_position).normalized()
	projectile.direction = direction
	projectile.rotation = direction.angle()
	
	# Add to scene
	get_parent().add_child(projectile)
	print("Projectile spawned!")
