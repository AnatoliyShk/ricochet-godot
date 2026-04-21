extends CharacterBody2D

@export var move_speed: float = 375.0
@export var projectile_scene: PackedScene
@export var laser_sight_enabled: bool = true
@export var max_health: int = 5
@export var invincibility_duration: float = 1.0  # Seconds of invincibility after hit
@export var knockback_strength: float = 200.0  # Reduced from 300
@export var max_ammo: int = 5
@export var reload_duration: float = 3.0

@onready var camera = $Camera2D
@onready var laser_sight = $LaserSight
@onready var shoot_sound = $ShootSound if has_node("ShootSound") else null
@onready var sprite = $Sprite2D if has_node("Sprite2D") else null

var can_shoot: bool = true
var shoot_cooldown: float = 0.2
var current_health: int
var current_ammo: int
var is_invincible: bool = false
var is_reloading: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO

func _ready():
	# Show/hide laser sight based on setting
	if laser_sight and laser_sight_enabled:
		laser_sight.visible = true
	elif laser_sight:
		laser_sight.visible = false
	
	# Initialize health and ammo
	current_health = max_health
	current_ammo = max_ammo
	add_to_group("player")
	# Defer so UILayer is ready before first update
	call_deferred("update_health_bar")
	call_deferred("update_ammo_bar")


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
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and can_shoot:
			shoot()

func shoot():
	if not projectile_scene:
		return
	if not can_shoot or is_reloading or current_ammo <= 0:
		return

	current_ammo -= 1
	update_ammo_bar()

	if shoot_sound:
		shoot_sound.pitch_scale = randf_range(0.9, 1.1)
		shoot_sound.play()

	can_shoot = false
	await get_tree().create_timer(shoot_cooldown).timeout
	can_shoot = true

	var projectile = projectile_scene.instantiate()
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - global_position).normalized()
	projectile.direction = direction
	projectile.rotation = direction.angle()
	projectile.global_position = global_position
	projectile.shooter = self
	get_tree().root.add_child(projectile)

	if camera and camera.has_method("apply_shake"):
		camera.apply_shake(3.0)

	if current_ammo <= 0:
		reload()


func reload():
	if is_reloading:
		return
	is_reloading = true
	var tween = create_tween()
	tween.tween_method(_update_reload_progress, 0.0, 1.0, reload_duration)
	await tween.finished
	current_ammo = max_ammo
	is_reloading = false
	update_ammo_bar()


func _update_reload_progress(progress: float):
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_reload_progress"):
		hud.set_reload_progress(progress)


func update_ammo_bar():
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_ammo"):
		hud.set_ammo(current_ammo, max_ammo)

func take_damage(amount: int, from_position: Vector2 = Vector2.ZERO):
	if is_invincible:
		return

	current_health -= amount

	if from_position != Vector2.ZERO:
		var knockback_dir = (global_position - from_position).normalized()
		knockback_velocity = knockback_dir * knockback_strength

	update_health_bar()

	var dmg_fx = get_tree().get_first_node_in_group("damage_effect")
	if dmg_fx and dmg_fx.has_method("trigger"):
		dmg_fx.trigger()

	flash_damage()

	is_invincible = true
	await get_tree().create_timer(invincibility_duration).timeout
	is_invincible = false

	if current_health <= 0:
		die()

func update_health_bar():
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_health"):
		hud.set_health(current_health, max_health)
	update_crt_hp_display()

func update_crt_hp_display():
	# Find the CRT overlay and update shader
	var crt_overlay = get_tree().get_first_node_in_group("crt_overlay")
	if crt_overlay and crt_overlay is CanvasLayer:
		var color_rect = crt_overlay.get_node_or_null("ColorRect")
		if color_rect and color_rect.material and color_rect.material is ShaderMaterial:
			color_rect.material.set_shader_parameter("player_hp", current_health)
			color_rect.material.set_shader_parameter("player_max_hp", max_health)

func flash_damage():
	if sprite:
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(sprite):
			sprite.modulate = Color.WHITE

func die():
	get_tree().reload_current_scene()

func _process(_delta):
	# Blink sprite when invincible
	if is_invincible and sprite:
		sprite.modulate.a = 0.5 if int(Time.get_ticks_msec() / 100) % 2 == 0 else 1.0
	elif sprite:
		sprite.modulate.a = 1.0
	
	# Shooting with direct input check (backup method)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and can_shoot:
		shoot()
