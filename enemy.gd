extends CharacterBody2D

const _HIT_SFX = [
	preload("res://Audio/Enemy/enemy_hit_sound_1.mp3"),
	preload("res://Audio/Enemy/enemy_hit_sound_2.mp3"),
	preload("res://Audio/Enemy/enemy_hit_sound_3.mp3"),
]

@export var max_health: int = 10
@export var move_speed: float = 225.0
@export var melee_damage: int = 1
@export var attack_range: float = 150.0  # Increased for testing
@export var attack_cooldown: float = 1.0  # Seconds between attacks
@export var detection_range: float = 99999.0
@export var knockback_strength: float = 400.0  # How hard to push back when hit

var current_health: int
var attack_timer: float = 0.0
var player: Node2D = null
var is_attacking: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO

var swing_arc_dir: float = 0.0
var swing_sweep: float = 0.0   # 0..1, advancdes during active phase
var swing_phase: String = ""   # "", "windup", "active", "recovery"

const SWING_HALF_ARC: float = PI / 3.0  # 60° each side = 120° total
const SWING_RADIUS: float = 52.0

const SEPARATION_RADIUS := 110.0
const SEPARATION_FORCE  := 320.0
const ROOM_BOUNDS := Rect2(0.0, 0.0, 2500.0, 2100.0)

var path_update_timer: float = 0.0
const PATH_UPDATE_INTERVAL: float = 0.2

var _stuck_timer: float = 0.0
var _stuck_pos_check: Vector2 = Vector2.ZERO
var _detour_timer: float = 0.0
var _detour_target: Vector2 = Vector2.ZERO
const STUCK_CHECK_INTERVAL: float = 0.6
const STUCK_DISTANCE: float = 35.0
const DETOUR_DURATION: float = 1.4

var is_dead: bool = false
var angular_velocity: float = 0.0

var _anim_sprite: AnimatedSprite2D = null
var _react_anim_timer: float = 0.0
const REACT_ANIM_DURATION: float = 0.65

@onready var health_bar = $HealthBar if has_node("HealthBar") else null
@onready var sprite = $Sprite2D if has_node("Sprite2D") else null
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var _col_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null

func _ready():
	current_health = max_health
	add_to_group("enemies")
	if health_bar:
		health_bar.hide()
	if sprite:
		sprite.hide()
	_setup_animated_sprite()
	_fit_collision_to_sprite()
	_setup_bullet_hitbox()

	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	_create_hp_bar_node()

func _setup_animated_sprite() -> void:
	var frames := SpriteFrames.new()

	frames.add_animation("walk")
	frames.set_animation_speed("walk", 8.0)
	frames.set_animation_loop("walk", true)
	for i in 4:
		frames.add_frame("walk", load("res://Enemies/Base/animations/Walking/south-east/frame_%03d.png" % i) as Texture2D)

	frames.add_animation("attack")
	frames.set_animation_speed("attack", 14.0)
	frames.set_animation_loop("attack", false)
	for i in 9:
		frames.add_frame("attack", load("res://Enemies/Base/animations/attack/main/frame_%03d.png" % i) as Texture2D)

	frames.add_animation("idle_s")
	frames.set_animation_loop("idle_s", true)
	frames.add_frame("idle_s", load("res://Enemies/Base/rotations/south.png") as Texture2D)

	frames.add_animation("idle_se")
	frames.set_animation_loop("idle_se", true)
	frames.add_frame("idle_se", load("res://Enemies/Base/rotations/south-east.png") as Texture2D)

	_anim_sprite = AnimatedSprite2D.new()
	_anim_sprite.sprite_frames = frames
	_anim_sprite.scale = Vector2(2.5, 2.5)
	_anim_sprite.play("idle_s")
	add_child(_anim_sprite)
	sprite = _anim_sprite

func _process(delta):
	queue_redraw()
	if _react_anim_timer > 0.0:
		_react_anim_timer = maxf(_react_anim_timer - delta, 0.0)
	_update_animation()

func _fit_collision_to_sprite() -> void:
	if not _col_shape:
		return
	var cap := CapsuleShape2D.new()
	cap.radius = 22.0
	cap.height = 60.0
	_col_shape.shape = cap
	_col_shape.position = Vector2.ZERO


func _setup_bullet_hitbox() -> void:
	var scr := GDScript.new()
	scr.source_code = """
extends Area2D
var enemy_ref: Node = null
func take_damage(amount: int, from_pos: Vector2 = Vector2.ZERO) -> void:
\tif enemy_ref and is_instance_valid(enemy_ref):
\t\tenemy_ref.take_damage(amount, from_pos)
func trigger_attack_anim() -> void:
\tif enemy_ref and is_instance_valid(enemy_ref):
\t\tenemy_ref.trigger_attack_anim()
"""
	scr.reload()
	var area := Area2D.new()
	area.set_script(scr)
	area.set("enemy_ref", self)
	area.collision_layer = 4  # layer 3 — separate from physics (layer 1) and projectiles (layer 2)
	area.collision_mask = 0
	area.add_to_group("enemy_hitbox")
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(340.0, 340.0)  # 136px sprite × 2.5 scale
	cs.shape = rect
	area.add_child(cs)
	add_child(area)


func _apply_separation() -> void:
	var push := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not is_instance_valid(other):
			continue
		var diff: Vector2 = global_position - (other.global_position as Vector2)
		var dist: float = diff.length()
		if dist < SEPARATION_RADIUS and dist > 0.5:
			push += diff.normalized() * (SEPARATION_RADIUS - dist) / SEPARATION_RADIUS
	if push != Vector2.ZERO:
		velocity += push * SEPARATION_FORCE


func _check_out_of_bounds() -> void:
	if not ROOM_BOUNDS.has_point(global_position):
		die()


func _start_detour() -> void:
	if not player:
		return
	var to_player := (player.global_position - global_position).normalized()
	var perp := Vector2(-to_player.y, to_player.x) * (1.0 if randf() > 0.5 else -1.0)
	_detour_target = global_position + perp * randf_range(120.0, 250.0) + to_player * 80.0
	_detour_timer = DETOUR_DURATION


func trigger_attack_anim() -> void:
	if not _anim_sprite or is_dead:
		return
	_react_anim_timer = REACT_ANIM_DURATION
	_anim_sprite.play("attack")

func _update_animation() -> void:
	if not _anim_sprite or is_dead:
		return

	if _react_anim_timer > 0.0:
		return

	if is_attacking:
		if _anim_sprite.animation != "attack":
			_anim_sprite.play("attack")
		return

	var moving := velocity.length() > 10.0
	if moving:
		_anim_sprite.flip_h = velocity.x < -10.0
		if _anim_sprite.animation != "walk":
			_anim_sprite.play("walk")
	else:
		var dir_to_player := (player.global_position - global_position) if player else Vector2.DOWN
		_anim_sprite.flip_h = dir_to_player.x < 0
		var target_anim := "idle_se" if abs(dir_to_player.x) > abs(dir_to_player.y) * 0.5 else "idle_s"
		if _anim_sprite.animation != target_anim:
			_anim_sprite.play(target_anim)

func _physics_dead(delta: float) -> void:
	velocity = knockback_velocity
	knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 3.5 * delta)
	rotation += angular_velocity * delta
	angular_velocity = lerpf(angular_velocity, 0.0, 3.0 * delta)
	move_and_slide()


func _physics_process(delta):
	if is_dead:
		_physics_dead(delta)
		return

	if not player:
		return

	attack_timer = max(attack_timer - delta, 0.0)
	var distance_to_player = global_position.distance_to(player.global_position)

	if knockback_velocity.length() > 10:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 8 * delta)
		move_and_slide()
		return

	if is_attacking:
		velocity = Vector2.ZERO
		return

	if distance_to_player < detection_range:
		_stuck_timer  = maxf(_stuck_timer  - delta, 0.0)
		_detour_timer = maxf(_detour_timer - delta, 0.0)

		path_update_timer = max(path_update_timer - delta, 0.0)
		if path_update_timer <= 0.0:
			path_update_timer = PATH_UPDATE_INTERVAL
			nav_agent.target_position = _detour_target if _detour_timer > 0.0 \
				else player.global_position

		# Stuck check — if barely moved and not attacking, pick a detour
		if _stuck_timer <= 0.0:
			_stuck_timer = STUCK_CHECK_INTERVAL
			if not is_attacking and distance_to_player > attack_range * 1.5 \
					and _detour_timer <= 0.0 \
					and global_position.distance_to(_stuck_pos_check) < STUCK_DISTANCE:
				_start_detour()
			_stuck_pos_check = global_position

		if not nav_agent.is_navigation_finished():
			var next_pos = nav_agent.get_next_path_position()
			var direction = (next_pos - global_position).normalized()
			velocity = direction * move_speed
			_apply_separation()
			move_and_slide()

			if sprite and direction.x != 0:
				sprite.flip_h = direction.x < 0
		else:
			velocity = Vector2.ZERO

		_check_out_of_bounds()

		if attack_timer <= 0:
			for i in get_slide_collision_count():
				var col = get_slide_collision(i)
				if col.get_collider().is_in_group("player"):
					attack_player()
					attack_timer = attack_cooldown
					break
	else:
		velocity = Vector2.ZERO
		nav_agent.target_position = global_position

func attack_player():
	if not player or not player.has_method("take_damage"):
		return

	is_attacking = true
	swing_arc_dir = (player.global_position - global_position).angle()

	# Damage is instant at the moment of collision
	player.take_damage(melee_damage, global_position)

	# Swing arc plays as hit-confirmation visual
	swing_phase = "active"
	swing_sweep = 0.0
	queue_redraw()
	var tween = create_tween()
	tween.tween_property(self, "swing_sweep", 1.0, 0.22)
	await tween.finished
	if is_dead:
		return

	swing_phase = "recovery"
	queue_redraw()
	await get_tree().create_timer(0.25).timeout
	if is_dead:
		return

	swing_phase = ""
	swing_sweep = 0.0
	is_attacking = false
	queue_redraw()

func take_damage(amount: int, from_position: Vector2 = Vector2.ZERO):
	var sfx := AudioStreamPlayer.new()
	sfx.stream = _HIT_SFX[randi() % _HIT_SFX.size()]
	sfx.pitch_scale = randf_range(0.9, 1.1)
	get_tree().root.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
	var hud_nodes := get_tree().get_nodes_in_group("hud")
	if hud_nodes.size() > 0:
		hud_nodes[0].show_damage_popup(amount, global_position + Vector2(0, -80))
	current_health -= amount

	if from_position != Vector2.ZERO:
		var dir := (global_position - from_position).normalized()
		if current_health <= 0:
			knockback_velocity = dir * knockback_strength
		else:
			global_position += dir * 6.0

	flash_damage()
	
	update_health_bar()
	
	if current_health <= 0:
		die()

func flash_damage():
	if sprite:
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(sprite) and not is_dead:
			sprite.modulate = Color.WHITE

func update_health_bar():
	queue_redraw()

func die():
	is_dead = true
	is_attacking = false
	swing_phase = ""
	angular_velocity = randf_range(-4.0, 4.0)

	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0

	if health_bar:
		health_bar.hide()
	if sprite:
		sprite.modulate = Color(0.25, 0.08, 0.08)

	var hud_nodes = get_tree().get_nodes_in_group("hud")
	if hud_nodes.size() > 0:
		hud_nodes[0].add_score(300)
		hud_nodes[0].show_score_popup(300, global_position)

func _create_hp_bar_node() -> void:
	var scr := GDScript.new()
	scr.source_code = """
extends Node2D
var enemy_ref: Node = null
func _process(_d: float) -> void:
\tqueue_redraw()
func _draw() -> void:
\tif not enemy_ref or not is_instance_valid(enemy_ref) or enemy_ref.is_dead:
\t\treturn
\tvar anim_spr = enemy_ref._anim_sprite
\tif not anim_spr or not anim_spr.sprite_frames:
\t\treturn
\tvar tex = anim_spr.sprite_frames.get_frame_texture(anim_spr.animation, anim_spr.frame)
\tif not tex:
\t\treturn
\tvar bw: float = float(tex.get_width()) * float(anim_spr.scale.x) * 0.5
\tvar bh: float = 6.0
\tvar bx: float = -bw * 0.5
\tvar by: float = -(float(tex.get_height()) * float(anim_spr.scale.y) * 0.25)
\tdraw_rect(Rect2(bx, by, bw, bh), Color(0.15, 0.0, 0.0))
\tvar frac: float = clampf(float(enemy_ref.current_health) / float(enemy_ref.max_health), 0.0, 1.0)
\tdraw_rect(Rect2(bx, by, bw * frac, bh), Color(1.0, 0.12, 0.12))
"""
	scr.reload()
	var bar := Node2D.new()
	bar.set_script(scr)
	bar.set("enemy_ref", self)
	add_child(bar)

func make_boss() -> void:
	max_health = 80
	current_health = 80
	move_speed = 180.0
	add_to_group("boss_enemy")
	if sprite:
		sprite.modulate = Color(1.2, 0.25, 0.25)
	queue_redraw()

func _draw():
	match swing_phase:
		"active":
			var tip = swing_arc_dir - SWING_HALF_ARC + SWING_HALF_ARC * 2.0 * swing_sweep
			draw_arc(Vector2.ZERO, SWING_RADIUS,
				swing_arc_dir - SWING_HALF_ARC, tip,
				max(2, int(20 * swing_sweep)), Color(1.0, 1.0, 0.9, 0.95), 4.5)
			draw_line(Vector2.ZERO, Vector2(cos(tip), sin(tip)) * SWING_RADIUS,
				Color.WHITE, 3.0)
		"recovery":
			draw_arc(Vector2.ZERO, SWING_RADIUS,
				swing_arc_dir - SWING_HALF_ARC, swing_arc_dir + SWING_HALF_ARC,
				20, Color(1.0, 0.45, 0.45, 0.35), 3.0)
