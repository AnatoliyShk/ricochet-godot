extends CharacterBody2D

@export var max_health: int = 3
@export var move_speed: float = 150.0
@export var melee_damage: int = 1
@export var attack_range: float = 150.0  # Increased for testing
@export var attack_cooldown: float = 1.0  # Seconds between attacks
@export var detection_range: float = 800.0
@export var knockback_strength: float = 400.0  # How hard to push back when hit

var current_health: int
var attack_timer: float = 0.0
var player: Node2D = null
var is_attacking: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO

var swing_arc_dir: float = 0.0
var swing_sweep: float = 0.0   # 0..1, advances during active phase
var swing_phase: String = ""   # "", "windup", "active", "recovery"

const SWING_HALF_ARC: float = PI / 3.0  # 60° each side = 120° total
const SWING_RADIUS: float = 52.0

var path_update_timer: float = 0.0
const PATH_UPDATE_INTERVAL: float = 0.2

var is_dead: bool = false
var angular_velocity: float = 0.0

@onready var health_bar = $HealthBar if has_node("HealthBar") else null
@onready var sprite = $Sprite2D if has_node("Sprite2D") else null
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

func _ready():
	current_health = max_health
	add_to_group("enemies")
	update_health_bar()
	
	# Find player
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")

func _process(_delta):
	if swing_phase != "":
		queue_redraw()

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
		path_update_timer = max(path_update_timer - delta, 0.0)
		if path_update_timer <= 0.0:
			path_update_timer = PATH_UPDATE_INTERVAL
			nav_agent.target_position = player.global_position

		if not nav_agent.is_navigation_finished():
			var next_pos = nav_agent.get_next_path_position()
			var direction = (next_pos - global_position).normalized()
			velocity = direction * move_speed
			move_and_slide()

			if sprite and direction.x != 0:
				sprite.flip_h = direction.x < 0
		else:
			velocity = Vector2.ZERO

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
	current_health -= amount

	if from_position != Vector2.ZERO:
		var knockback_dir = (global_position - from_position).normalized()
		knockback_velocity = knockback_dir * knockback_strength

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
	if health_bar and health_bar is ProgressBar:
		health_bar.max_value = max_health
		health_bar.value = current_health

func die():
	is_dead = true
	is_attacking = false
	swing_phase = ""
	angular_velocity = randf_range(-4.0, 4.0)

	remove_from_group("enemies")

	if health_bar:
		health_bar.hide()
	if sprite:
		sprite.modulate = Color(0.25, 0.08, 0.08)

	var hud_nodes = get_tree().get_nodes_in_group("hud")
	if hud_nodes.size() > 0:
		hud_nodes[0].add_score(300)
		hud_nodes[0].show_score_popup(300, global_position)

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
