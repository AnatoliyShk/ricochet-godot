extends CharacterBody2D

@export var move_speed: float = 300.0
@export var projectile_scene: PackedScene
@export var laser_sight_enabled: bool = true
@export var max_health: int = 5
@export var invincibility_duration: float = 1.0  # Seconds of invincibility after hit
@export var knockback_strength: float = 200.0  # Reduced from 300

@onready var camera = $Camera2D
@onready var laser_sight = $LaserSight
@onready var shoot_sound = $ShootSound if has_node("ShootSound") else null
@onready var sprite = $Sprite2D if has_node("Sprite2D") else null
@onready var health_bar = $HealthBar if has_node("HealthBar") else null

var can_shoot: bool = true
var shoot_cooldown: float = 0.2
var current_health: int
var is_invincible: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO

func _ready():
	# Show/hide laser sight based on setting
	if laser_sight and laser_sight_enabled:
		laser_sight.visible = true
	elif laser_sight:
		laser_sight.visible = false
	
	# Initialize health
	current_health = max_health
	add_to_group("player")
	update_health_bar()
	print("Player HP: ", current_health, "/", max_health)

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
	
	# Apply knockback with faster decay
	if knockback_velocity.length() > 10:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 15 * delta)  # Faster decay
	else:
		# Reset knockback completely when very small
		knockback_velocity = Vector2.ZERO
		velocity = input_dir * move_speed
	
	move_and_slide()

func _input(event):
	# Toggle fullscreen with F11
	if event is InputEventKey:
		if event.keycode == KEY_F11 and event.pressed:
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	
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
	
	# Play shooting sound
	if shoot_sound:
		# Optional: Randomize pitch for variety
		shoot_sound.pitch_scale = randf_range(0.9, 1.1)
		shoot_sound.play()
	
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
	print("Projectile instance valid: ", is_instance_valid(projectile))
	print("Projectile has script: ", projectile.get_script() != null)
	
	# Camera shake on shoot (optional)
	if camera and camera.has_method("apply_shake"):
		camera.apply_shake(3.0)

func take_damage(amount: int, from_position: Vector2 = Vector2.ZERO):
	print("TAKE_DAMAGE CALLED! Amount: ", amount, " Current HP: ", current_health)
	
	if is_invincible:
		print("  -> Player is invincible, ignoring damage")
		return
	
	current_health -= amount
	print("  -> Player took damage! New HP: ", current_health, "/", max_health)
	
	# Apply knockback away from attacker
	if from_position != Vector2.ZERO:
		var knockback_dir = (global_position - from_position).normalized()
		knockback_velocity = knockback_dir * knockback_strength
		print("  -> Knockback applied: ", knockback_velocity)
	
	# Update health bar
	update_health_bar()
	
	# Flash effectddd
	flash_damage()
	
	# Become invincible briefly
	is_invincible = true
	print("  -> Player is now invincible for ", invincibility_duration, " seconds")
	await get_tree().create_timer(invincibility_duration).timeout
	is_invincible = false
	print("  -> Player invincibility ended")
	
	# Check if dead
	if current_health <= 0:
		die()

func update_health_bar():
	if health_bar and health_bar is ProgressBar:
		health_bar.max_value = max_health
		health_bar.value = current_health

func flash_damage():
	if sprite:
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(sprite):
			sprite.modulate = Color.WHITE

func die():
	print("Player died!")
	# You can add game over screen, restart, etc.
	get_tree().reload_current_scene()

func _process(_delta):
	# Blink sprite when invincible
	if is_invincible and sprite:
		sprite.modulate.a = 0.5 if int(Time.get_ticks_msec() / 100) % 2 == 0 else 1.0
	elif sprite:
		sprite.modulate.a = 1.0
