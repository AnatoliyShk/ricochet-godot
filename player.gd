extends CharacterBody2D

@export var move_speed: float = 375.0
@export var projectile_scene: PackedScene
@export var laser_sight_enabled: bool = true
@export var max_health: int = 6
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

var _arm_hud_layer: CanvasLayer = null
var _arm_hud_pivot: Node2D = null
var _arm_hud_sprite: Sprite2D = null
var _arm_hud_rifle: Sprite2D = null

var _current_weapon: String = "gun"
var _shield_body: StaticBody2D = null
var _shield_collision: CollisionShape2D = null
var _weapon_wheel_layer: CanvasLayer = null
var _weapon_wheel_node = null
var _wheel_hovered: String = "gun"

const DASH_DURATION        := 0.1
const DASH_RELOAD          := 2.0
const DASH_SPEED_MULT      := 3.0
const DASH_RICOCHET_BONUS  := 0.3
const DASH_RICOCHET_MULT   := 3.5

const SHOTGUN_SPREAD_DEG   := 24.0

const LASER_DAMAGE_INTERVAL := 0.2
const LASER_CRANK_TICK_ANGLE  := PI / 6.0
const LASER_FULL_SPIN_CHARGE  := 0.2

# Mutable weapon stats (modified by upgrades)
var gun_damage: float          = 7.0
var gun_fire_rate_mult: float  = 1.0

var sg_particle_count: int     = 4
var sg_particle_damage: float  = 4.0
var sg_particle_lifetime: float = 2.0
var sg_reload_bonus: float     = 0.0   # added seconds to reload per upgrade

var laser_max_energy: float    = 1.0
var laser_reload_time: float   = 3.0
var laser_damage_per_tick: float = 1.0  # 5 HP/s × 0.2s interval
var laser_beam_width: float    = 5.0

var revolver_damage: float     = 20.0

const REVOLVER_SECOND_DELAY       := 0.2
const REVOLVER_FIRST_SPEED_MULT   := 1.0 / 1.5
const REVOLVER_SECOND_SPEED_MULT  := 2.5
const REVOLVER_GLOW_FIRST_MULT    := 2.0
const REVOLVER_GLOW_SECOND_MULT   := 2.2
const REVOLVER_COLLISION_RADIUS   := 20.0
const REVOLVER_RECOIL_TIME        := 1.5
const REVOLVER_MAX_AMMO           := 12
const LASER_HIT_RADIUS      := 28.0

var _is_dashing: bool              = false
var _dash_timer: float             = 0.0
var _dash_reload_timer: float      = 0.0
var _dash_direction: Vector2       = Vector2.RIGHT
var _dash_speed_mult: float        = DASH_SPEED_MULT
var _last_input_dir: Vector2       = Vector2.RIGHT
var _dash_ricochet_cooldown: float = 0.0

var _laser_energy: float        = 1.0
var _laser_reload_timer: float  = 0.0
var _laser_active: bool         = false
var _laser_damage_timer: float  = 0.0
var _laser_node: Node2D         = null
var _laser_points: Array[Vector2] = []
var _laser_ricochet_idx: int    = -1
var _laser_hit_enemies: Array   = []
var _crank_angle_accum: float   = 0.0

var _revolver_proj1: Node        = null
var _revolver_proj2: Node        = null
var _revolver_fired: bool        = false
var _revolver_shoot_dir: Vector2 = Vector2.RIGHT
var _revolver_ammo: int          = REVOLVER_MAX_AMMO
var _revolver_scroll_count: int  = 0

var is_immortal: bool = false

var _rifle_sfx: AudioStreamMP3
var _shotgun_sfx: AudioStreamMP3
var _laser_sound: AudioStreamPlayer
var _revolver_collide_sound: AudioStreamPlayer

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
	_setup_sounds()
	_setup_arm_hud()


func _setup_weapon_visuals():
	# Single torso sprite — flips horizontally based on facing direction
	var torso_tex = load("res://player/torso.png")
	if sprite and torso_tex:
		sprite.texture = torso_tex
		sprite.region_enabled = false
		sprite.scale = Vector2(2.3, 2.3)
		sprite.position = Vector2(0, 0)
		sprite.z_index = 0

	# Hand sprite rotates inside WeaponPivot toward the mouse.
	var hand_tex = load("res://player/hand.png")
	if hand_tex:
		arms_sprite = Sprite2D.new()
		arms_sprite.texture = hand_tex
		arms_sprite.centered = true
		arms_sprite.scale = Vector2(2.3, 2.3)
		arms_sprite.position = Vector2(0, 0)
		arms_sprite.z_index = 2
		weapon_pivot.add_child(arms_sprite)

	var rifle_tex = load("res://player/riffle.png")
	if rifle_tex:
		_arm_hud_rifle = Sprite2D.new()
		_arm_hud_rifle.texture = rifle_tex
		_arm_hud_rifle.centered = true
		_arm_hud_rifle.scale = Vector2(1.035, 1.035)
		_arm_hud_rifle.position = Vector2(20.0, 8.0)
		_arm_hud_rifle.z_index = 1
		weapon_pivot.add_child(_arm_hud_rifle)

	muzzle_marker.position = Vector2(40, 0)

	# Muzzle flash sprite, hidden until a shot fires.
	var flash_tex = load("res://muzzle_flash.png")
	if flash_tex:
		muzzle_flash_sprite = Sprite2D.new()
		muzzle_flash_sprite.texture = flash_tex
		muzzle_flash_sprite.visible = false
		muzzle_flash_sprite.scale = Vector2(3.0, 3.0)
		muzzle_flash_sprite.z_index = 2
		muzzle_marker.add_child(muzzle_flash_sprite)

func _setup_arm_hud() -> void:
	_arm_hud_layer = CanvasLayer.new()
	_arm_hud_layer.layer = 3
	add_child(_arm_hud_layer)

	_arm_hud_pivot = Node2D.new()
	_arm_hud_layer.add_child(_arm_hud_pivot)

	var hand_tex = load("res://player/hand.png")
	if hand_tex:
		_arm_hud_sprite = Sprite2D.new()
		_arm_hud_sprite.texture = hand_tex
		_arm_hud_sprite.centered = true
		_arm_hud_sprite.scale = Vector2(4.6, 4.6)
		_arm_hud_sprite.position = Vector2(40.0, 0.0)
		_arm_hud_sprite.rotation = PI * 0.75
		_arm_hud_pivot.add_child(_arm_hud_sprite)



func _play_one_shot(stream: AudioStream, pitch_min: float = 1.0, pitch_max: float = 1.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.pitch_scale = randf_range(pitch_min, pitch_max)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _make_sfx(path: String, loop: bool = false, pitch: float = 1.0) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream := load(path) as AudioStreamMP3
	if loop:
		stream.loop = true
	player.stream = stream
	player.pitch_scale = pitch
	add_child(player)
	return player

func _setup_sounds() -> void:
	_rifle_sfx   = load("res://Audio/Weapon/rifle_shot_sound_1.mp3")
	_shotgun_sfx = load("res://Audio/Weapon/shotgun_shot_sound_1.mp3")
	_laser_sound          = _make_sfx("res://Audio/Weapon/electro_beam_1.mp3", true, 0.5)
	_revolver_collide_sound = _make_sfx("res://Audio/Weapon/revolver_bullets_collide_sound_1.mp3")

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
		if input_dir != Vector2.ZERO:
			_dash_direction = input_dir
		velocity = _dash_direction * move_speed * _dash_speed_mult
	else:
		knockback_velocity = Vector2.ZERO
		velocity = input_dir * move_speed

	move_and_slide()

	if _current_weapon == "laser":
		_process_laser(delta)

	_check_revolver_collision()

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

	if event is InputEventMouseButton and event.pressed \
			and (event.button_index == MOUSE_BUTTON_WHEEL_UP \
			or event.button_index == MOUSE_BUTTON_WHEEL_DOWN) \
			and ctrl_mode and _current_weapon == "laser":
		_crank_laser_starter()

	if event is InputEventMouseButton and event.pressed \
			and (event.button_index == MOUSE_BUTTON_WHEEL_UP \
			or event.button_index == MOUSE_BUTTON_WHEEL_DOWN) \
			and _current_weapon == "revolver":
		_spin_revolver_visual()

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
		elif can_shoot and _current_weapon == "shotgun":
			_shoot_shotgun()
		elif not _revolver_fired and _current_weapon == "revolver":
			_shoot_revolver()

func shoot():
	if not projectile_scene:
		return
	if not can_shoot or is_reloading or current_ammo <= 0:
		return

	current_ammo -= 1
	update_ammo_bar(velocity)

	_play_one_shot(_rifle_sfx, 0.9, 1.1)

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
	projectile.damage = gun_damage
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

func reload(duration: float = -1.0):
	if is_reloading:
		return
	var dur := reload_duration if duration < 0.0 else duration
	is_reloading = true
	var tween = create_tween()
	tween.tween_method(_update_reload_progress, 0.0, 1.0, dur)
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
	if is_invincible or is_immortal:
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


func upgrade_hp() -> void:
	max_health += 2
	update_health_bar()

func upgrade_heal() -> void:
	current_health = max_health
	update_health_bar()

func gun_upgrade_ammo(level: int) -> void:
	match level:
		1: max_ammo += 1; gun_damage = max(1.0, gun_damage - 1)
		2: max_ammo += 2; gun_damage = max(1.0, gun_damage - 1)
		3: max_ammo += 4
	current_ammo = min(current_ammo, max_ammo)
	update_ammo_bar()

func gun_upgrade_damage(level: int) -> void:
	match level:
		1: gun_damage += 2; shoot_cooldown *= 1.05
		2: gun_damage += 4; shoot_cooldown *= 1.10
		3: gun_damage += 8

func gun_upgrade_fire_rate(level: int) -> void:
	match level:
		1: shoot_cooldown *= 0.95; gun_damage = max(1.0, gun_damage - 2)
		2: shoot_cooldown *= 0.90; gun_damage = max(1.0, gun_damage - 2)
		3: shoot_cooldown *= 0.85

func shotgun_upgrade_particles(level: int) -> void:
	match level:
		1: sg_particle_count += 1; sg_particle_damage = max(2.0, sg_particle_damage - 1)
		2: sg_particle_count += 2; sg_particle_damage = max(2.0, sg_particle_damage - 2)
		3: sg_particle_count += 4; sg_particle_damage = max(2.0, sg_particle_damage - 1)

func shotgun_upgrade_damage(level: int) -> void:
	match level:
		1: sg_particle_damage = max(2.0, sg_particle_damage + 3); sg_reload_bonus += 2.0
		2: sg_particle_damage = max(2.0, sg_particle_damage + 6); sg_reload_bonus += 4.0
		3: sg_particle_damage = max(2.0, sg_particle_damage + 9); sg_reload_bonus += 2.0

func shotgun_upgrade_lifetime(level: int) -> void:
	match level:
		1: sg_particle_lifetime += 1.0; sg_particle_damage = max(2.0, sg_particle_damage - 1)
		2: sg_particle_lifetime += 1.5
		3: sg_particle_lifetime = 4.0; sg_particle_damage = max(2.0, sg_particle_damage - 3)

func laser_upgrade_battery(level: int) -> void:
	match level:
		1:
			laser_max_energy = max(1.0, laser_max_energy + 0.5)
			laser_damage_per_tick = max(0.2, laser_damage_per_tick - 3 * LASER_DAMAGE_INTERVAL)
		2:
			laser_max_energy = max(1.0, laser_max_energy + 1.0)
			laser_damage_per_tick = max(0.2, laser_damage_per_tick - 2 * LASER_DAMAGE_INTERVAL)
		3:
			laser_max_energy = max(1.0, laser_max_energy + 3.0)
			laser_damage_per_tick = max(0.2, laser_damage_per_tick - 3 * LASER_DAMAGE_INTERVAL)

func laser_upgrade_damage(level: int) -> void:
	match level:
		1:
			laser_damage_per_tick += 2 * LASER_DAMAGE_INTERVAL
			laser_beam_width = max(2.0, laser_beam_width - 3)
		2:
			laser_damage_per_tick += 5 * LASER_DAMAGE_INTERVAL
			laser_beam_width = max(2.0, laser_beam_width - 5)
		3:
			laser_damage_per_tick += 10 * LASER_DAMAGE_INTERVAL
			laser_beam_width = max(2.0, laser_beam_width - 8)
	if _laser_node and is_instance_valid(_laser_node):
		_laser_node.queue_free()
		_laser_node = null

func laser_upgrade_width(level: int) -> void:
	match level:
		1:
			laser_beam_width = max(2.0, laser_beam_width + 2)
			laser_max_energy = max(1.0, laser_max_energy - 0.5)
		2:
			laser_beam_width = max(2.0, laser_beam_width + 4)
			laser_max_energy = max(1.0, laser_max_energy - 1.0)
		3:
			laser_beam_width = max(2.0, laser_beam_width + 8)
	if _laser_node and is_instance_valid(_laser_node):
		_laser_node.queue_free()
		_laser_node = null


func die():
	for proj in get_tree().get_nodes_in_group("projectiles"):
		proj.queue_free()
	if _laser_node and is_instance_valid(_laser_node):
		_laser_node.queue_free()
		_laser_node = null
	# Clear visual particles/effects
	for node in get_tree().get_nodes_in_group("impact_effect"):
		node.queue_free()
	for child in get_tree().root.get_children():
		var scr := child.get_script() as Script
		if scr != null:
			if "blood" in scr.resource_path or "impact" in scr.resource_path:
				child.queue_free()
	_show_game_over()

func _show_game_over() -> void:
	get_tree().paused = true

	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 36)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title := Label.new()
	title.text = "GAME OVER"
	title.add_theme_font_size_override("font_size", 80)
	title.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var messages := ["Totally ricocheted", "U cooked", "Try again Boomer"]
	var msg := Label.new()
	msg.text = messages[randi() % messages.size()]
	msg.add_theme_font_size_override("font_size", 36)
	msg.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(msg)

	var btn := Button.new()
	btn.text = "RESTART"
	btn.custom_minimum_size = Vector2(260, 60)
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color", Color(1.0, 0.28, 0.28))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.55, 0.55))

	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(0.07, 0.0, 0.02, 0.9)
	sn.set_border_width_all(2)
	sn.border_color = Color(0.85, 0.12, 0.12)
	sn.set_corner_radius_all(8)
	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(0.18, 0.02, 0.03, 1.0)
	sh.set_border_width_all(2)
	sh.border_color = Color(1.0, 0.18, 0.18)
	sh.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", sn)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("focus", sn)

	btn.pressed.connect(func():
		layer.queue_free()
		get_tree().paused = false
		get_tree().reload_current_scene()
	)
	vbox.add_child(btn)


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
	var show_arms   := weapon_id in ["gun", "shotgun", "laser", "revolver"]
	var show_shield := weapon_id == "shield"

	if arms_sprite:
		arms_sprite.visible = show_arms
	if muzzle_flash_sprite:
		muzzle_flash_sprite.visible = false
	if laser_sight:
		laser_sight.visible = weapon_id == "gun" and laser_sight_enabled

	if _shield_body:
		_shield_body.visible = show_shield
	if _shield_collision:
		_shield_collision.disabled = not show_shield

	if weapon_id != "laser":
		_stop_laser_beam()
		_laser_active = false
		if _laser_sound:
			_laser_sound.stop()
	if weapon_id == "revolver":
		_revolver_ammo = REVOLVER_MAX_AMMO
		_revolver_fired = false
		_revolver_scroll_count = 0
		var hud_r = get_tree().get_first_node_in_group("hud")
		if hud_r and hud_r.has_method("reset_revolver_drums"):
			hud_r.reset_revolver_drums()
	else:
		_revolver_fired = false

	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_weapon_mode"):
		hud.set_weapon_mode(weapon_id)


func _show_weapon_wheel() -> void:
	if _weapon_wheel_layer:
		return
	var music = get_tree().get_first_node_in_group("music")
	if music:
		music.volume_db = linear_to_db(1.0 / 3.0)
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
	var music = get_tree().get_first_node_in_group("music")
	if music:
		music.volume_db = music.get_meta("base_volume_db", 0.0)
	if _weapon_wheel_node:
		_wheel_hovered = _weapon_wheel_node.hovered_weapon
	_equip_weapon(_wheel_hovered)
	_weapon_wheel_layer.queue_free()
	_weapon_wheel_layer = null
	_weapon_wheel_node = null


func _shoot_shotgun() -> void:
	if not projectile_scene:
		return
	if not can_shoot or is_reloading or current_ammo <= 0:
		return

	current_ammo -= 1
	update_ammo_bar(velocity)

	_play_one_shot(_shotgun_sfx, 0.82, 1.05)

	can_shoot = false
	await get_tree().create_timer(shoot_cooldown * 1.4).timeout
	can_shoot = true

	var mouse_pos := get_global_mouse_position()
	var base_dir := (mouse_pos - global_position).normalized()

	for i in sg_particle_count:
		var t := float(i) / float(max(sg_particle_count - 1, 1))
		var spread_rad := deg_to_rad(lerp(-SHOTGUN_SPREAD_DEG * 0.5,
			SHOTGUN_SPREAD_DEG * 0.5, t))
		var spread_dir := base_dir.rotated(spread_rad)

		var proj = projectile_scene.instantiate()
		proj.direction = spread_dir
		proj.rotation = spread_dir.angle()
		proj.global_position = muzzle_marker.global_position
		proj.shooter = self
		proj.bullet_length = 10.0
		proj.bullet_width = 3.0
		proj.trail_length = 15.0
		proj.trail_width = 1.5
		proj.lifetime = sg_particle_lifetime
		proj.damage = sg_particle_damage
		proj.explode_on_death = true
		get_tree().root.add_child(proj)

	_show_muzzle_flash()
	if camera and camera.has_method("apply_shake"):
		camera.apply_shake(5.5)

	if current_ammo <= 0:
		reload(reload_duration + sg_reload_bonus)


func _get_or_create_laser_node() -> Node2D:
	if _laser_node and is_instance_valid(_laser_node):
		return _laser_node
	_laser_node = Node2D.new()
	_laser_node.name = "LaserBeam"
	_laser_node.z_index = 5
	get_tree().root.add_child(_laser_node)

	_make_line2d(_laser_node, "YellowGlow", laser_beam_width + 9.0, Color(1.0, 0.9, 0.1, 0.18))
	_make_line2d(_laser_node, "YellowCore", laser_beam_width,       Color(1.0, 0.95, 0.2))
	_make_line2d(_laser_node, "GreenGlow",  laser_beam_width + 9.0, Color(0.2, 1.0, 0.4, 0.18))
	_make_line2d(_laser_node, "GreenCore",  laser_beam_width,       Color(0.35, 1.0, 0.5))

	_laser_node.visible = false
	return _laser_node


func _make_line2d(parent: Node, nm: String, w: float, col: Color) -> void:
	var l := Line2D.new()
	l.name = nm
	l.width = w
	l.default_color = col
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode   = Line2D.LINE_CAP_ROUND
	parent.add_child(l)


func _laser_trace() -> void:
	_laser_points = [muzzle_marker.global_position]
	_laser_ricochet_idx = -1
	_laser_hit_enemies.clear()
	var pos: Vector2 = muzzle_marker.global_position
	var dir: Vector2 = (get_global_mouse_position() - global_position).normalized()
	var space := get_world_2d().direct_space_state
	var exclude: Array = [self]
	var wall_bounces: int = 0

	for _i in 12:
		var q := PhysicsRayQueryParameters2D.create(pos, pos + dir * 2000.0)
		q.exclude = exclude
		q.collide_with_areas = false
		q.collide_with_bodies = true
		var hit := space.intersect_ray(q)

		if not hit:
			_laser_points.append(pos + dir * 2000.0)
			break

		var col = hit.collider

		if col.is_in_group("walls") or (col is StaticBody2D and not col.is_in_group("shield")):
			_laser_points.append(hit.position)
			if _laser_ricochet_idx == -1:
				_laser_ricochet_idx = _laser_points.size() - 1
			wall_bounces += 1
			if wall_bounces >= 3:
				break
			var n: Vector2 = hit.normal
			if abs(n.x) > abs(n.y):
				dir.x = -dir.x
			else:
				dir.y = -dir.y
			pos = hit.position + dir * 4.0
			exclude = [self]
		elif _laser_ricochet_idx != -1 and col.is_in_group("enemies"):
			_laser_hit_enemies.append(col)
			exclude.append(col)
			pos = hit.position + dir * 4.0
		else:
			_laser_points.append(pos + dir * 2000.0)
			break


func _update_laser_beam() -> void:
	var node := _get_or_create_laser_node()
	var y_glow := node.get_node_or_null("YellowGlow") as Line2D
	var y_core := node.get_node_or_null("YellowCore") as Line2D
	var g_glow := node.get_node_or_null("GreenGlow")  as Line2D
	var g_core := node.get_node_or_null("GreenCore")  as Line2D

	if _laser_ricochet_idx == -1:
		var all := PackedVector2Array(_laser_points)
		if y_glow: y_glow.points = all
		if y_core: y_core.points = all
		if g_glow: g_glow.points = PackedVector2Array()
		if g_core: g_core.points = PackedVector2Array()
	else:
		var pre  := PackedVector2Array(_laser_points.slice(0, _laser_ricochet_idx + 1))
		var post := PackedVector2Array(_laser_points.slice(_laser_ricochet_idx))
		if y_glow: y_glow.points = pre
		if y_core: y_core.points = pre
		if g_glow: g_glow.points = post
		if g_core: g_core.points = post

	if y_core: y_core.width = laser_beam_width
	if y_glow: y_glow.width = laser_beam_width + 9.0
	if g_core: g_core.width = laser_beam_width
	if g_glow: g_glow.width = laser_beam_width + 9.0

	var t          := Time.get_ticks_msec() * 0.001
	var energy_frac := clampf(_laser_energy / laser_max_energy, 0.0, 1.0)
	var shimmer_amp := 1.0 - energy_frac          # 0 at full charge, 1 at empty
	var brightness  := (1.0 - shimmer_amp * 0.2) \
		+ shimmer_amp * 0.3 * sin(t * 11.0) \
		+ shimmer_amp * 0.2 * sin(t * 17.3 + 0.8)
	node.modulate = Color(brightness, brightness, brightness, 1.0)
	node.visible = true


func _stop_laser_beam() -> void:
	if _laser_node and is_instance_valid(_laser_node):
		_laser_node.visible = false


func _laser_check_damage() -> void:
	if _laser_ricochet_idx == -1:
		return
	for enemy in _laser_hit_enemies:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(int(ceil(laser_damage_per_tick)), Vector2.ZERO)
	# Check if post-ricochet beam hits the player themselves
	for i in range(_laser_ricochet_idx, _laser_points.size() - 1):
		var a: Vector2 = _laser_points[i]
		var b: Vector2 = _laser_points[i + 1]
		var seg := b - a
		var seg_len := seg.length()
		if seg_len < 1.0:
			continue
		var t := clampf((global_position - a).dot(seg) / (seg_len * seg_len), 0.0, 1.0)
		if global_position.distance_to(a + seg * t) < LASER_HIT_RADIUS:
			take_damage(int(ceil(laser_damage_per_tick)), Vector2.ZERO)
			break


func _process_laser(delta: float) -> void:
	var hud = get_tree().get_first_node_in_group("hud")

	if _laser_reload_timer > 0.0:
		_laser_reload_timer = maxf(_laser_reload_timer - delta, 0.0)
		if _laser_reload_timer <= 0.0:
			_laser_energy = laser_max_energy
		_stop_laser_beam()
		_laser_sound.stop()
		if hud and hud.has_method("set_energy"):
			hud.set_energy(1.0 - _laser_reload_timer / laser_reload_time, true)
		return

	var firing := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
		and not ctrl_mode and _laser_energy > 0.0

	if firing:
		_laser_active = true
		_laser_energy = maxf(_laser_energy - delta, 0.0)
		_laser_damage_timer = maxf(_laser_damage_timer - delta, 0.0)

		_laser_trace()
		_update_laser_beam()

		if _laser_damage_timer <= 0.0:
			_laser_check_damage()
			_laser_damage_timer = LASER_DAMAGE_INTERVAL

		if _laser_energy <= 0.0:
			_laser_active = false
			_laser_reload_timer = laser_reload_time
			_stop_laser_beam()
	else:
		if _laser_active:
			_laser_active = false
		_stop_laser_beam()

	if hud and hud.has_method("set_energy"):
		hud.set_energy(_laser_energy / laser_max_energy, false)

	if _laser_active:
		if not _laser_sound.playing:
			_laser_sound.play()
	else:
		_laser_sound.stop()


func _spawn_projectile(dir: Vector2) -> Node:
	var proj = projectile_scene.instantiate()
	proj.direction = dir
	proj.rotation = dir.angle()
	proj.global_position = muzzle_marker.global_position
	proj.shooter = self
	get_tree().root.add_child(proj)
	return proj


func _shoot_revolver() -> void:
	if not projectile_scene or _revolver_fired or _revolver_ammo <= 0:
		return

	_revolver_fired = true
	_revolver_ammo -= 2

	if shoot_sound:
		shoot_sound.pitch_scale = randf_range(0.85, 1.05)
		shoot_sound.play()

	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("shoot_revolver_drum"):
		hud.shoot_revolver_drum()
	var muzzle_screen: Vector2 = get_viewport().get_canvas_transform() \
		* muzzle_marker.global_position
	if hud and hud.has_method("eject_shells_at"):
		hud.eject_shells_at(muzzle_screen, 2, velocity)

	var _is_glowing := _revolver_scroll_count >= 6
	_revolver_scroll_count = 0
	_revolver_shoot_dir = (get_global_mouse_position() - global_position).normalized()
	_revolver_proj1 = _spawn_projectile(_revolver_shoot_dir)
	_revolver_proj1.damage = revolver_damage
	_revolver_proj1.speed *= REVOLVER_GLOW_FIRST_MULT if _is_glowing else REVOLVER_FIRST_SPEED_MULT
	_revolver_proj2 = null
	_show_muzzle_flash()
	if camera and camera.has_method("apply_shake"):
		camera.apply_shake(3.5)

	await get_tree().create_timer(REVOLVER_SECOND_DELAY).timeout

	if is_instance_valid(_revolver_proj1) and _current_weapon == "revolver":
		var aim_dir: Vector2 = (_revolver_proj1.global_position \
			- muzzle_marker.global_position).normalized()
		_revolver_proj2 = _spawn_projectile(aim_dir)
		_revolver_proj2.damage = revolver_damage
		_revolver_proj2.speed = _revolver_proj1.speed * \
			(REVOLVER_GLOW_SECOND_MULT if _is_glowing else REVOLVER_SECOND_SPEED_MULT)
		_show_muzzle_flash()
		if camera and camera.has_method("apply_shake"):
			camera.apply_shake(3.5)

	await get_tree().create_timer(REVOLVER_RECOIL_TIME).timeout

	if _revolver_ammo <= 0:
		await get_tree().create_timer(reload_duration).timeout
		_revolver_ammo = REVOLVER_MAX_AMMO
		var hud2 = get_tree().get_first_node_in_group("hud")
		if hud2 and hud2.has_method("reset_revolver_drums"):
			hud2.reset_revolver_drums()

	_revolver_fired = false


func _check_revolver_collision() -> void:
	if not is_instance_valid(_revolver_proj1) or not is_instance_valid(_revolver_proj2):
		return
	if _revolver_proj1.global_position.distance_to(_revolver_proj2.global_position) \
			> REVOLVER_COLLISION_RADIUS:
		return

	_revolver_collide_sound.play()
	var p1 = _revolver_proj1
	var p2 = _revolver_proj2
	_revolver_proj1 = null
	_revolver_proj2 = null

	var p1_pos: Vector2 = p1.global_position
	var p2_pos: Vector2 = p2.global_position
	var normal: Vector2 = (p2_pos - p1_pos).normalized()
	if normal == Vector2.ZERO:
		normal = Vector2.RIGHT

	# Y-shape: ±35° from original shoot direction — always predictable
	var spread := deg_to_rad(35.0)
	p1.direction = _revolver_shoot_dir.rotated(spread)
	p1.rotation  = p1.direction.angle()
	p2.direction = _revolver_shoot_dir.rotated(-spread)
	p2.rotation  = p2.direction.angle()

	p1.ricochet_count += 1
	p2.ricochet_count += 1
	if p1.has_method("_apply_ricochet_visuals"):
		p1._apply_ricochet_visuals()
	if p2.has_method("_apply_ricochet_visuals"):
		p2._apply_ricochet_visuals()


func _spin_revolver_visual() -> void:
	_revolver_scroll_count += 1
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("spin_revolver_visual"):
		hud.spin_revolver_visual(_revolver_scroll_count >= 6)


func _crank_laser_starter() -> void:
	var hud = get_tree().get_first_node_in_group("hud")

	# Spin the visual wheel by one tick
	if hud and hud.has_method("spin_starter"):
		hud.spin_starter(LASER_CRANK_TICK_ANGLE)

	# Accumulate angle; apply charge every full 360°
	_crank_angle_accum += LASER_CRANK_TICK_ANGLE
	while _crank_angle_accum >= TAU:
		_crank_angle_accum -= TAU
		if _laser_reload_timer > 0.0:
			_laser_reload_timer = maxf(_laser_reload_timer - LASER_FULL_SPIN_CHARGE, 0.0)
			if _laser_reload_timer <= 0.0:
				_laser_energy = laser_max_energy
		elif _laser_energy < laser_max_energy:
			_laser_energy = minf(_laser_energy + LASER_FULL_SPIN_CHARGE, laser_max_energy)

	if hud and hud.has_method("set_energy"):
		var reloading := _laser_reload_timer > 0.0
		var frac := (1.0 - _laser_reload_timer / laser_reload_time) if reloading \
			else (_laser_energy / laser_max_energy)
		hud.set_energy(frac, reloading)


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
	var aim_right: bool = get_global_mouse_position().x >= global_position.x

	# Torso flips to face movement direction
	var move_right: bool = velocity.x > 10.0 if abs(velocity.x) > 10.0 else aim_right
	if sprite:
		sprite.flip_h = not move_right

	# Screen-space arm in bottom-right corner points toward mouse
	if _arm_hud_pivot:
		var vp_size := get_viewport_rect().size
		var corner := vp_size - Vector2(80.0, 80.0)
		_arm_hud_pivot.position = corner
		var mouse_screen := get_viewport().get_mouse_position()
		_arm_hud_pivot.rotation = (mouse_screen - corner).angle()
		if _arm_hud_sprite:
			_arm_hud_sprite.flip_v = not move_right

	# Pivot at shoulder; hand top-left corner anchored there, rotates toward mouse
	if weapon_pivot:
		weapon_pivot.position = Vector2(0.0, 0.0)
		weapon_pivot.rotation = (get_global_mouse_position() - weapon_pivot.global_position).angle()

	# Blink torso when invincible
	var alpha := 0.5 if is_invincible and int(Time.get_ticks_msec() / 100) % 2 == 0 else 1.0
	if sprite:
		sprite.modulate.a = alpha
	
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
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and can_shoot \
			and not ctrl_mode and _current_weapon == "shotgun":
		_shoot_shotgun()
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not _revolver_fired \
			and not ctrl_mode and _current_weapon == "revolver":
		_shoot_revolver()
