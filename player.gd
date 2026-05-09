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
@onready var weapon_pivot = $WeaponPivot
@onready var muzzle_marker = $WeaponPivot/Muzzle

var can_shoot: bool = true
var shoot_cooldown: float = 0.2
var current_health: int
var current_ammo: int
var is_invincible: bool = false
var is_reloading: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var ctrl_mode: bool = false
var _hand_cursor: ImageTexture = null
var arms_sprite: Sprite2D = null
var muzzle_flash_sprite: Sprite2D = null

var _current_weapon: String = "gun"
var _shield_body: StaticBody2D = null
var _shield_collision: CollisionShape2D = null
var _weapon_wheel_layer: CanvasLayer = null
var _weapon_wheel_node = null
var _wheel_hovered: String = "gun"

const DASH_DURATION        := 0.5
const DASH_RELOAD          := 2.0
const DASH_SPEED_MULT      := 2.0
const DASH_RICOCHET_BONUS  := 0.4
const DASH_RICOCHET_MULT   := 4.0

var _is_dashing: bool              = false
var _dash_timer: float             = 0.0
var _dash_reload_timer: float      = 0.0
var _dash_direction: Vector2       = Vector2.RIGHT
var _dash_speed_mult: float        = DASH_SPEED_MULT
var _last_input_dir: Vector2       = Vector2.RIGHT
var _dash_ricochet_cooldown: float = 0.0

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
	_hand_cursor = _build_hand_cursor()
	_setup_weapon_visuals()
	_setup_shield()


func _setup_weapon_visuals():
	# Body: swap to scifi sprite sheet, show first frame (64×64)
	var body_tex = load("res://scifi_character_rifle.png")
	if sprite and body_tex:
		sprite.texture = body_tex
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0, 0, 64, 32)
		sprite.scale = Vector2(3.0, 3.0)
		sprite.position = Vector2(0, 0)

	# Arms/rifle sprite inside WeaponPivot.
	# grip_pixel=14, image_center=32 → sprite_pos = (32-14)*scale = 63 at scale 3.5
	var arms_tex = load("res://arms_rifle.png")
	if arms_tex:
		arms_sprite = Sprite2D.new()
		arms_sprite.texture = arms_tex
		arms_sprite.scale = Vector2(3.5, 3.5)
		arms_sprite.position = Vector2(10, 0)
		arms_sprite.z_index = 1
		weapon_pivot.add_child(arms_sprite)

	# muzzle_in_pivot = sprite_pos.x + (60-32)*scale = 10 + 98 = 108
	muzzle_marker.position = Vector2(108, 0)

	# Muzzle flash sprite, hidden until a shot fires.
	var flash_tex = load("res://muzzle_flash.png")
	if flash_tex:
		muzzle_flash_sprite = Sprite2D.new()
		muzzle_flash_sprite.texture = flash_tex
		muzzle_flash_sprite.visible = false
		muzzle_flash_sprite.scale = Vector2(3.0, 3.0)
		muzzle_flash_sprite.z_index = 2
		muzzle_marker.add_child(muzzle_flash_sprite)

func _physics_process(delta):
	# Dash timers
	if _is_dashing:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_is_dashing = false
			_dash_reload_timer = DASH_RELOAD
	elif _dash_reload_timer > 0.0:
		_dash_reload_timer = maxf(_dash_reload_timer - delta, 0.0)
	if _dash_ricochet_cooldown > 0.0:
		_dash_ricochet_cooldown = maxf(_dash_ricochet_cooldown - delta, 0.0)

	# Update dash bar in HUD
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_dash"):
		var prog := 1.0 - (_dash_reload_timer / DASH_RELOAD) if _dash_reload_timer > 0.0 else 1.0
		hud.set_dash(_is_dashing, prog if not _is_dashing else _dash_timer / DASH_DURATION)

	# Movement input
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
	if input_dir != Vector2.ZERO:
		_last_input_dir = input_dir

	# Apply knockback with faster decay
	if knockback_velocity.length() > 10:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 15 * delta)
	elif _is_dashing:
		velocity = _dash_direction * move_speed * _dash_speed_mult
	else:
		knockback_velocity = Vector2.ZERO
		velocity = input_dir * move_speed

	move_and_slide()

	# Dash wall ricochet — axis-aligned reflection, 150ms cooldown prevents re-triggering
	if _is_dashing and _dash_ricochet_cooldown <= 0.0:
		for i in get_slide_collision_count():
			var col = get_slide_collision(i)
			if col.get_collider().is_in_group("walls"):
				var normal := col.get_normal()
				if abs(normal.x) > abs(normal.y):
					_dash_direction.x = -_dash_direction.x
				else:
					_dash_direction.y = -_dash_direction.y
				_dash_direction = _dash_direction.normalized()
				global_position += _dash_direction * 12.0
				_dash_timer += DASH_RICOCHET_BONUS
				_dash_speed_mult = DASH_RICOCHET_MULT
				_dash_ricochet_cooldown = 0.15
				break

func _try_start_dash() -> void:
	if _is_dashing or _dash_reload_timer > 0.0:
		return
	_dash_direction = _last_input_dir
	_dash_speed_mult = DASH_SPEED_MULT
	_is_dashing = true
	_dash_timer = DASH_DURATION


func _input(event):
	if event is InputEventKey and event.keycode == KEY_SPACE \
			and event.pressed and not event.echo:
		_try_start_dash()

	if event is InputEventKey and event.keycode == KEY_TAB and not event.echo:
		if event.pressed:
			_show_weapon_wheel()
		else:
			_hide_weapon_wheel()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if ctrl_mode:
			var hud = get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("try_collect_shell"):
				var screen_pos = get_viewport().get_mouse_position()
				if hud.try_collect_shell(screen_pos):
					current_ammo = min(current_ammo + 1, max_ammo)
					update_ammo_bar()
		elif can_shoot and _current_weapon == "gun":
			shoot()

func shoot():
	if not projectile_scene:
		return
	if not can_shoot or is_reloading or current_ammo <= 0:
		return

	current_ammo -= 1
	update_ammo_bar(velocity)

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
	projectile.global_position = muzzle_marker.global_position
	projectile.shooter = self
	get_tree().root.add_child(projectile)

	_show_muzzle_flash()

	if camera and camera.has_method("apply_shake"):
		camera.apply_shake(3.0)

	if current_ammo <= 0:
		reload()


func _show_muzzle_flash():
	if not muzzle_flash_sprite:
		return
	muzzle_flash_sprite.visible = true
	muzzle_flash_sprite.rotation = randf_range(-PI, PI)
	muzzle_flash_sprite.scale = Vector2(randf_range(2.5, 3.5), randf_range(2.5, 3.5))
	await get_tree().create_timer(0.07).timeout
	if is_instance_valid(muzzle_flash_sprite):
		muzzle_flash_sprite.visible = false

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


func update_ammo_bar(move_dir: Vector2 = Vector2.ZERO):
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_ammo"):
		hud.set_ammo(current_ammo, max_ammo, move_dir)

func take_damage(amount: int, from_position: Vector2 = Vector2.ZERO):
	if is_invincible:
		return

	current_health -= amount

	if from_position != Vector2.ZERO:
		var knockback_dir = (global_position - from_position).normalized()
		knockback_velocity = knockback_dir * knockback_strength

	update_health_bar()
	_spawn_blood(from_position)

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

func _spawn_blood(from_position: Vector2 = Vector2.ZERO):
	var spray_dir = Vector2.ZERO
	if from_position != Vector2.ZERO:
		spray_dir = (global_position - from_position).normalized()

	var splatter = Node2D.new()
	splatter.set_script(load("res://blood_splatter.gd"))
	splatter.global_position = global_position
	splatter.z_index = -1
	splatter.set("spray_dir", spray_dir)
	get_tree().current_scene.add_child(splatter)

	# Raycast outward in 8 directions to find nearby wall surfaces
	var space = get_world_2d().direct_space_state
	var ray_dirs = [
		Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN,
		Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(),
		Vector2(1, -1).normalized(), Vector2(-1, -1).normalized(),
	]
	var wall_hits: Array = []
	for dir in ray_dirs:
		var q = PhysicsRayQueryParameters2D.create(global_position, global_position + dir * 72)
		q.exclude = [self]
		q.collide_with_bodies = true
		q.collide_with_areas = false
		var hit = space.intersect_ray(q)
		if hit and hit.collider.is_in_group("walls"):
			var close = false
			for wp in wall_hits:
				if wp.distance_to(hit.position) < 28:
					close = true
					break
			if not close:
				wall_hits.append(hit.position)

	for hit_pos in wall_hits:
		var wb = Node2D.new()
		wb.set_script(load("res://blood_wall.gd"))
		wb.global_position = hit_pos
		wb.z_index = 0
		get_tree().current_scene.add_child(wb)


func upgrade_ammo() -> void:
	max_ammo += 2
	current_ammo = max_ammo
	update_ammo_bar()


func upgrade_hp() -> void:
	max_health += 1
	update_health_bar()


func upgrade_heal() -> void:
	current_health = max_health
	update_health_bar()


func die():
	get_tree().reload_current_scene()


func _setup_shield() -> void:
	_shield_body = StaticBody2D.new()
	_shield_body.set_script(load("res://shield.gd"))
	_shield_body.collision_layer = 8  # layer 4 — bullets detect all layers, player only checks layer 1
	_shield_body.collision_mask = 0

	_shield_collision = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(15.0, 75.0)
	_shield_collision.shape = rect
	_shield_collision.disabled = true
	_shield_body.add_child(_shield_collision)

	weapon_pivot.add_child(_shield_body)
	_shield_body.position = Vector2(60.0, 0.0)
	_shield_body.visible = false


func _equip_weapon(weapon_id: String) -> void:
	_current_weapon = weapon_id
	var gun_active := weapon_id == "gun"

	if arms_sprite:
		arms_sprite.visible = gun_active
	if muzzle_flash_sprite:
		muzzle_flash_sprite.visible = false
	if laser_sight:
		laser_sight.visible = gun_active and laser_sight_enabled

	if _shield_body:
		_shield_body.visible = not gun_active
	if _shield_collision:
		_shield_collision.disabled = gun_active


func _show_weapon_wheel() -> void:
	if _weapon_wheel_layer:
		return
	_wheel_hovered = _current_weapon

	_weapon_wheel_layer = CanvasLayer.new()
	_weapon_wheel_layer.layer = 20
	get_tree().root.add_child(_weapon_wheel_layer)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.45)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapon_wheel_layer.add_child(bg)

	_weapon_wheel_node = load("res://weapon_wheel.gd").new()
	_weapon_wheel_node.current_weapon = _current_weapon
	_weapon_wheel_node.hovered_weapon = _current_weapon
	_weapon_wheel_node.player_ref = self
	_weapon_wheel_layer.add_child(_weapon_wheel_node)


func _hide_weapon_wheel() -> void:
	if not _weapon_wheel_layer:
		return
	if _weapon_wheel_node:
		_wheel_hovered = _weapon_wheel_node.hovered_weapon
	_equip_weapon(_wheel_hovered)
	_weapon_wheel_layer.queue_free()
	_weapon_wheel_layer = null
	_weapon_wheel_node = null


func _build_hand_cursor() -> ImageTexture:
	var S := 3  # scale factor — 1 unit = 3px
	var W := 32 * S
	var H := 32 * S
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var yellow := Color(1.0, 0.92, 0.0, 1.0)
	var black  := Color(0.0, 0.0, 0.0, 1.0)

	# Shapes defined at 32x32 units, rendered at S px each
	# Each entry: [x, y, w, h]
	var outline_rects := [
		# index finger outline
		[11, 0, 8, 22],
		# middle finger outline
		[19, 5, 7, 17],
		# ring finger outline
		[19, 5, 7, 17],  # shared column handled below
		# palm outline
		[7, 18, 18, 12],
		# thumb outline
		[4, 20, 7, 8],
	]

	# Draw black outline shapes (1 unit larger on each side)
	_fill_img_rect(img, 10, 0,  10, 24, black, S)   # index finger
	_fill_img_rect(img, 18, 4,   9, 19, black, S)   # middle finger
	_fill_img_rect(img, 22, 6,   8, 17, black, S)   # ring finger
	_fill_img_rect(img, 25, 8,   7, 15, black, S)   # pinky
	_fill_img_rect(img,  6, 18, 22, 13, black, S)   # palm
	_fill_img_rect(img,  3, 19,  8,  9, black, S)   # thumb

	# Draw yellow fill (inset 1 unit from outline)
	_fill_img_rect(img, 11, 1,   8, 22, yellow, S)  # index finger
	_fill_img_rect(img, 19, 5,   7, 17, yellow, S)  # middle finger
	_fill_img_rect(img, 23, 7,   6, 15, yellow, S)  # ring finger
	_fill_img_rect(img, 26, 9,   5, 13, yellow, S)  # pinky
	_fill_img_rect(img,  7, 19, 20, 11, yellow, S)  # palm
	_fill_img_rect(img,  4, 20,  6,  7, yellow, S)  # thumb

	return ImageTexture.create_from_image(img)


func _fill_img_rect(img: Image, x: int, y: int, w: int, h: int, color: Color, scale: int):
	var px := x * scale
	var py := y * scale
	var pw := w * scale
	var ph := h * scale
	for iy in ph:
		for ix in pw:
			var fx := px + ix
			var fy := py + iy
			if fx < img.get_width() and fy < img.get_height():
				img.set_pixel(fx, fy, color)

func _process(_delta):
	# Rotate weapon pivot toward mouse; flip arms when aiming left
	if weapon_pivot:
		weapon_pivot.rotation = (get_global_mouse_position() - global_position).angle()
	if arms_sprite:
		arms_sprite.flip_v = cos(weapon_pivot.rotation) < 0

	# Blink sprite when invincible
	if is_invincible and sprite:
		sprite.modulate.a = 0.5 if int(Time.get_ticks_msec() / 100) % 2 == 0 else 1.0
	elif sprite:
		sprite.modulate.a = 1.0
	
	# Ctrl mode: block shooting, show hand cursor
	ctrl_mode = Input.is_key_pressed(KEY_CTRL)
	if ctrl_mode:
		Input.set_custom_mouse_cursor(_hand_cursor, Input.CURSOR_ARROW, Vector2(18, 6))
	else:
		Input.set_custom_mouse_cursor(null)

	# Shooting with direct input check (backup method)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and can_shoot \
			and not ctrl_mode and _current_weapon == "gun":
		shoot()
