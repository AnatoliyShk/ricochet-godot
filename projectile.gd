extends Area2D

@export var speed: float = 600.0
@export var damage: int = 1
@export var lifetime: float = 3.0
@export var bullet_color: Color = Color.YELLOW
@export var bullet_color_after_ricochet: Color = Color.GREEN
@export var bullet_length: float = 20.0
@export var bullet_width: float = 6.0
@export var trail_enabled: bool = true
@export var trail_length: float = 30.0
@export var trail_width: float = 3.0
@export var trail_color: Color = Color.YELLOW
@export var trail_color_after_ricochet: Color = Color.GREEN
@export var ricochet_enabled: bool = true
@export var max_ricochets: int = 4
@export var ricochet_speed_loss: float = 0.8
@export var show_impact_effects: bool = true
@export var play_impact_sound: bool = true

var direction: Vector2 = Vector2.RIGHT
var shooter = null
var has_left_shooter: bool = false
var ricochet_count: int = 0
var has_ricocheted: bool = false  # Track if bullet bounced at least once
var trail_line: Line2D = null  # Reference to trail for color change

@onready var impact_sound = $ImpactSound if has_node("ImpactSound") else null

func _ready():
	set_collision_mask_value(1, true)
	set_collision_layer_value(2, true)

	# Add trail effect
	if trail_enabled:
		trail_line = Line2D.new()
		trail_line.width = trail_width
		trail_line.default_color = trail_color
		trail_line.add_point(Vector2.ZERO)
		trail_line.add_point(Vector2(-trail_length, 0))
		add_child(trail_line)
	
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()

func _draw():
	var current_color = _ricochet_color() if has_ricocheted else bullet_color
	
	draw_rect(Rect2(-bullet_length/2, -bullet_width/2, bullet_length, bullet_width), current_color)
	draw_rect(Rect2(-bullet_length/2, -bullet_width/4, bullet_length, bullet_width/2), Color.WHITE)
	var tip_points = PackedVector2Array([
		Vector2(bullet_length/2, 0),
		Vector2(bullet_length/2 - 5, -bullet_width/2),
		Vector2(bullet_length/2 - 5, bullet_width/2)
	])
	draw_colored_polygon(tip_points, Color.WHITE)

func _physics_process(delta):
	# Track when bullet has cleared the shooter
	if shooter and not has_left_shooter:
		if global_position.distance_to(shooter.global_position) > 50:
			has_left_shooter = true

	var motion = direction * speed * delta

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + motion
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [shooter] if shooter and not has_left_shooter else []

	var result = space_state.intersect_ray(query)

	if result:
		global_position = result.position
		_handle_hit(result.collider, result.normal)
	else:
		position += motion

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

var radius = 5.0
var max_radius = 20.0
var alpha = 1.0
var color = Color.WHITE

func _process(delta):
	radius += 80 * delta
	alpha -= 3.0 * delta
	if alpha <= 0:
		queue_free()
	queue_redraw()

func _draw():
	var c = color
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
	var c := _ricochet_color()
	if trail_line:
		trail_line.default_color = c
	queue_redraw()


func _handle_hit(body: Node, normal: Vector2):
	# Wall / shield ricochet
	if ricochet_enabled and ricochet_count < max_ricochets:
		var is_wall = body.is_in_group("walls") or body is StaticBody2D or body is TileMap
		if is_wall:
			if body.has_method("on_bullet_impact"):
				body.on_bullet_impact(global_position)
			play_impact_sound_effect()
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
	if body.is_in_group("enemies"):
		if has_ricocheted:
			spawn_impact_effect(global_position, Color.RED)
			play_impact_sound_effect()
			if body.has_method("take_damage"):
				body.take_damage(int(ceil(damage * _damage_multiplier())), global_position)
			queue_free()
		else:
			# Non-ricocheted bullet: enemy bats it back toward the player
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
