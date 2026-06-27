extends Area2D

const _RICOCHET_SFX = [
	preload("res://Audio/Weapon/richochet_sound_1.mp3"),
	preload("res://Audio/Weapon/richochet_sound_3.mp3"),
]

@export var speed: float = 600.0
@export var damage: float = 1.0
@export var lifetime: float = 4.0
@export var bullet_color: Color = Color.YELLOW
@export var bullet_color_after_ricochet: Color = Color.GREEN
@export var bullet_length: float = 22.0
@export var bullet_width: float = 7.0
@export var trail_enabled: bool = true
@export var trail_length: float = 38.0
@export var trail_width: float = 21.0
@export var trail_color: Color = Color.YELLOW
@export var trail_color_after_ricochet: Color = Color.GREEN
@export var ricochet_enabled: bool = true
@export var max_ricochets: int = 4
@export var ricochet_speed_loss: float = 0.8
@export var show_impact_effects: bool = true
@export var play_impact_sound: bool = true
@export var explode_on_death: bool = false

var direction: Vector2 = Vector2.RIGHT
var shooter = null
var has_left_shooter: bool = false
var ricochet_count: int = 0
var has_ricocheted: bool = false
var _trail_timer: float = 0.0
var _bat_exclude: Object = null
var _bat_exclude_timer: float = 0.0

static var _trail_scr: GDScript = null

@onready var impact_sound = $ImpactSound if has_node("ImpactSound") else null

func _ready():
	add_to_group("projectiles")
	set_collision_mask_value(1, true)
	set_collision_layer_value(2, true)

	# Lazy-init the shared circle script
	if trail_enabled and not _trail_scr:
		_trail_scr = GDScript.new()
		_trail_scr.source_code = """
extends Node2D
var col: Color = Color.WHITE
var alpha: float = 0.55
var radius: float = 5.0
func _process(delta: float) -> void:
\talpha -= delta * 2.8
\tif alpha <= 0.0:
\t\tqueue_free()
\tqueue_redraw()
func _draw() -> void:
\tdraw_circle(Vector2.ZERO, radius, Color(col.r, col.g, col.b, alpha))
\tdraw_arc(Vector2.ZERO, radius * 1.5, 0.0, TAU, 20, Color(col.r, col.g, col.b, alpha * 0.35), 1.2)
"""
		_trail_scr.reload()
	
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		if explode_on_death:
			_spawn_shotgun_explosion()
		queue_free()

func _draw():
	var current_color = _ricochet_color() if has_ricocheted else bullet_color

	# Outer triangle — tapers from wide back to sharp tip at front
	var pts := PackedVector2Array([
		Vector2( bullet_length / 2.0,  0.0),
		Vector2(-bullet_length / 2.0, -bullet_width / 2.0),
		Vector2(-bullet_length / 2.0,  bullet_width / 2.0),
	])
	draw_colored_polygon(pts, current_color)

	# Bright inner highlight
	var inner := PackedVector2Array([
		Vector2( bullet_length / 2.0,  0.0),
		Vector2(-bullet_length / 6.0, -bullet_width / 4.0),
		Vector2(-bullet_length / 6.0,  bullet_width / 4.0),
	])
	draw_colored_polygon(inner, Color(1.0, 1.0, 1.0, 0.6))

func _get_trail_color() -> Color:
	var c := _ricochet_color() if has_ricocheted else bullet_color
	return Color(c.r, c.g, c.b, 0.55)

func _spawn_trail_circle() -> void:
	if not _trail_scr or not is_instance_valid(get_tree()):
		return
	var node := Node2D.new()
	node.global_position = global_position
	node.set_script(_trail_scr)
	node.set("col", _get_trail_color())
	get_tree().root.add_child(node)

func _physics_process(delta):
	if trail_enabled:
		_trail_timer -= delta
		if _trail_timer <= 0.0:
			_trail_timer = 0.03
			_spawn_trail_circle()

	# Track when bullet has cleared the shooter
	if shooter and not has_left_shooter:
		if global_position.distance_to(shooter.global_position) > 50:
			has_left_shooter = true

	var motion = direction * speed * delta

	if _bat_exclude_timer > 0.0:
		_bat_exclude_timer -= delta
	else:
		_bat_exclude = null

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + motion
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0xFFFFFFFF & ~2  # all layers except layer 2 (other projectiles)
	var _excl: Array = []
	if shooter and not has_left_shooter:
		_excl.append(shooter)
	if _bat_exclude:
		_excl.append(_bat_exclude)
	query.exclude = _excl

	var result = space_state.intersect_ray(query)

	if result:
		global_position = result.position
		_handle_hit(result.collider, result.normal)
	else:
		position += motion

func _spawn_shotgun_explosion() -> void:
	var exp_color := _ricochet_color() if has_ricocheted else Color(1.0, 0.65, 0.1)
	spawn_impact_effect(global_position, exp_color)
	var ring := Node2D.new()
	ring.global_position = global_position
	var s := GDScript.new()
	s.source_code = """
extends Node2D
var radius: float = 4.0
var alpha: float = 0.85
var color: Color = Color(1.0, 0.55, 0.1)
func _process(delta):
\tradius += 160 * delta
\talpha -= 3.8 * delta
\tif alpha <= 0: queue_free()
\tqueue_redraw()
func _draw():
\tvar c: Color = color; c.a = alpha
\tdraw_arc(Vector2.ZERO, radius, 0, TAU, 24, c, 3.5)
\tvar c2: Color = color; c2.a = alpha * 0.35
\tdraw_circle(Vector2.ZERO, radius * 0.45, c2)
"""
	s.reload()
	ring.set_script(s)
	ring.set("color", exp_color)
	get_tree().root.add_child(ring)


func spawn_impact_effect(at_position: Vector2, impact_color: Color = Color.WHITE):
	if not show_impact_effects:
		return
	
	# Create simple impact effect with code
	var impact = Node2D.new()
	impact.global_position = at_position
	
	# Add script to make it animate
	var impact_script = GDScript.new()
	impact_script.source_code = """
extends Node2D

var radius: float = 5.0
var max_radius: float = 20.0
var alpha: float = 1.0
var color: Color = Color.WHITE

func _process(delta):
	radius += 80 * delta
	alpha -= 3.0 * delta
	if alpha <= 0:
		queue_free()
	queue_redraw()

func _draw():
	var c: Color = color
	c.a = alpha
	draw_circle(Vector2.ZERO, radius, c)
	if alpha > 0.5:
		draw_circle(Vector2.ZERO, radius * 0.4, Color.WHITE)
"""
	impact_script.reload()
	impact.set_script(impact_script)
	impact.set("color", impact_color)
	
	get_tree().root.add_child(impact)

func play_impact_sound_effect():
	if not play_impact_sound or not impact_sound:
		return
	
	# Detach sound from bullet so it keeps playing after bullet is destroyed
	if impact_sound.get_parent():
		impact_sound.get_parent().remove_child(impact_sound)
	
	# Add to scene root and play
	get_tree().root.add_child(impact_sound)
	impact_sound.global_position = global_position
	impact_sound.play()
	
	# Auto-delete sound after it finishes
	impact_sound.finished.connect(func(): impact_sound.queue_free())

func _play_ricochet_sound() -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _RICOCHET_SFX[randi() % _RICOCHET_SFX.size()]
	p.pitch_scale = randf_range(0.9, 1.1)
	get_tree().root.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _ricochet_color() -> Color:
	match ricochet_count:
		1: return Color.GREEN
		2: return Color(0.3, 0.6, 1.0)
		3: return Color(0.7, 0.2, 1.0)
		_: return Color(1.0, 0.55, 0.1)


func _damage_multiplier() -> float:
	match ricochet_count:
		2: return 1.5
		3: return 2.0
		_ : return 4.0 if ricochet_count >= 4 else 1.0


func _apply_ricochet_visuals() -> void:
	has_ricocheted = true
	queue_redraw()


func _handle_hit(body: Node, normal: Vector2):
	# Wall / shield ricochet
	if ricochet_enabled and ricochet_count < max_ricochets:
		var is_wall = body.is_in_group("walls") or body is StaticBody2D or body is TileMap
		if is_wall:
			if body.has_method("on_bullet_impact"):
				body.on_bullet_impact(global_position)
			_play_ricochet_sound()
			spawn_impact_effect(global_position, _ricochet_color() if has_ricocheted else Color.YELLOW)

			if body.is_in_group("shield"):
				# 90° deflection — perpendicular to incoming direction
				direction = Vector2(-direction.y, direction.x)
			elif abs(normal.x) > abs(normal.y):
				direction.x = -direction.x
			else:
				direction.y = -direction.y

			rotation = direction.angle()
			speed *= ricochet_speed_loss
			ricochet_count += 1
			global_position += direction * 4
			_apply_ricochet_visuals()
			return

	# Enemy hit
	if body.is_in_group("enemies") or body.is_in_group("enemy_hitbox"):
		if has_ricocheted:
			spawn_impact_effect(global_position, Color.RED)
			play_impact_sound_effect()
			if body.has_method("take_damage"):
				body.take_damage(int(ceil(damage * _damage_multiplier())), global_position)
			queue_free()
		else:
			# Non-ricocheted bullet: enemy bats it back toward the player
			if body.has_method("trigger_attack_anim"):
				body.trigger_attack_anim()
			_bat_exclude = body
			_bat_exclude_timer = 0.3
			var player_node = get_tree().get_first_node_in_group("player")
			if player_node:
				direction = (player_node.global_position - global_position).normalized()
				rotation = direction.angle()
				global_position += direction * 8
				spawn_impact_effect(global_position, Color.CYAN)
				play_impact_sound_effect()
				# Bullet continues — no queue_free
			else:
				spawn_impact_effect(global_position, Color.ORANGE)
				play_impact_sound_effect()
				queue_free()
		return

	# Player hit (redirected bullet coming back)
	if body.is_in_group("player"):
		spawn_impact_effect(global_position, Color.RED)
		play_impact_sound_effect()
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
		queue_free()
		return

	# Fallback
	spawn_impact_effect(global_position, Color.ORANGE)
	play_impact_sound_effect()
	queue_free()
