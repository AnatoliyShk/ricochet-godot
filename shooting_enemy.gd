extends CharacterBody2D

@export var max_health: int = 3
@export var move_speed: float = 120.0
@export var detection_range: float = 800.0
@export var min_distance: float = 150.0
@export var preferred_distance: float = 250.0
@export var max_shoot_distance: float = 450.0
@export var knockback_strength: float = 400.0

const SCORE_VALUE: int = 500
const MAX_AMMO: int = 3
const RELOAD_TIME: float = 3.0
const SHOOT_COOLDOWN: float = 0.65
const PATH_UPDATE_INTERVAL: float = 0.25

var current_health: int
var current_ammo: int = MAX_AMMO
var is_reloading: bool = false
var shoot_timer: float = 0.0
var path_update_timer: float = 0.0
var player: Node2D = null
var knockback_velocity: Vector2 = Vector2.ZERO
var is_dead: bool = false
var angular_velocity: float = 0.0

@onready var health_bar = $HealthBar if has_node("HealthBar") else null
@onready var sprite = $Sprite2D if has_node("Sprite2D") else null
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

var _projectile_scene: PackedScene = preload("res://projectile.tscn")

func _ready():
	current_health = max_health
	add_to_group("enemies")
	_update_health_bar()
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")


func _physics_process(delta):
	if is_dead:
		_physics_dead(delta)
		return
	if not player:
		return

	if knockback_velocity.length() > 10:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 8 * delta)
		move_and_slide()
		return

	var dist := global_position.distance_to(player.global_position)
	if dist < detection_range:
		_update_movement(delta, dist)
		_update_shooting(delta, dist)
	else:
		velocity = Vector2.ZERO


func _update_movement(delta: float, dist: float) -> void:
	if dist < min_distance:
		var flee_dir := (global_position - player.global_position).normalized()
		velocity = flee_dir * move_speed
		move_and_slide()
		if sprite:
			sprite.flip_h = flee_dir.x > 0
	elif dist > preferred_distance + 40.0:
		path_update_timer = max(path_update_timer - delta, 0.0)
		if path_update_timer <= 0.0:
			path_update_timer = PATH_UPDATE_INTERVAL
			var approach_target := player.global_position + \
				(global_position - player.global_position).normalized() * preferred_distance
			nav_agent.target_position = approach_target
		if not nav_agent.is_navigation_finished():
			var dir := (nav_agent.get_next_path_position() - global_position).normalized()
			velocity = dir * move_speed
			move_and_slide()
			if sprite and dir.x != 0:
				sprite.flip_h = dir.x < 0
		else:
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO
		var face_dir := (player.global_position - global_position).normalized()
		if sprite and face_dir.x != 0:
			sprite.flip_h = face_dir.x < 0


func _update_shooting(delta: float, dist: float) -> void:
	if is_reloading or current_ammo <= 0 or dist > max_shoot_distance:
		return
	shoot_timer = max(shoot_timer - delta, 0.0)
	if shoot_timer > 0.0:
		return
	_shoot()
	shoot_timer = SHOOT_COOLDOWN
	current_ammo -= 1
	if current_ammo <= 0:
		_start_reload()


func _shoot() -> void:
	var direction := (player.global_position - global_position).normalized()
	var projectile = _projectile_scene.instantiate()
	projectile.direction = direction
	projectile.rotation = direction.angle()
	projectile.global_position = global_position
	projectile.shooter = self
	get_tree().root.add_child(projectile)


func _start_reload() -> void:
	if is_reloading:
		return
	is_reloading = true
	await get_tree().create_timer(RELOAD_TIME).timeout
	if is_dead or not is_instance_valid(self):
		return
	current_ammo = MAX_AMMO
	is_reloading = false


func _physics_dead(delta: float) -> void:
	velocity = knockback_velocity
	knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 3.5 * delta)
	rotation += angular_velocity * delta
	angular_velocity = lerpf(angular_velocity, 0.0, 3.0 * delta)
	move_and_slide()


func take_damage(amount: int, from_position: Vector2 = Vector2.ZERO):
	if is_dead:
		return
	current_health -= amount
	if from_position != Vector2.ZERO:
		knockback_velocity = (global_position - from_position).normalized() * knockback_strength
	_flash_damage()
	_update_health_bar()
	if current_health <= 0:
		die()


func _flash_damage():
	if sprite:
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(sprite) and not is_dead:
			sprite.modulate = Color(0.4, 0.6, 1.0)


func _update_health_bar():
	if health_bar and health_bar is ProgressBar:
		health_bar.max_value = max_health
		health_bar.value = current_health


func die():
	is_dead = true
	angular_velocity = randf_range(-4.0, 4.0)
	remove_from_group("enemies")
	if health_bar:
		health_bar.hide()
	if sprite:
		sprite.modulate = Color(0.1, 0.1, 0.25)
	var hud_nodes = get_tree().get_nodes_in_group("hud")
	if hud_nodes.size() > 0:
		hud_nodes[0].add_score(SCORE_VALUE)
		hud_nodes[0].show_score_popup(SCORE_VALUE, global_position)
