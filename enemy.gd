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

@onready var health_bar = $HealthBar if has_node("HealthBar") else null
@onready var sprite = $Sprite2D if has_node("Sprite2D") else null

func _ready():
	current_health = max_health
	add_to_group("enemies")
	update_health_bar()
	
	# Find player
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	if not player:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)

	# Apply knockback
	if knockback_velocity.length() > 10:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 8 * delta)  # Decay knockback
		move_and_slide()
		return  # Skip normal movement while being knocked back
	
	# Move toward player or attack
	if distance_to_player < detection_range:
		if distance_to_player > attack_range:
			# Move closer to player
			var direction = (player.global_position - global_position).normalized()
			velocity = direction * move_speed
			move_and_slide()

			# Flip sprite based on direction
			if sprite and direction.x != 0:
				sprite.flip_h = direction.x < 0
		else:
			velocity = Vector2.ZERO
			attack_timer -= delta
			if attack_timer <= 0:
				attack_player()
				attack_timer = attack_cooldown
	else:
		velocity = Vector2.ZERO

func attack_player():
	if not player or not player.has_method("take_damage"):
		return

	is_attacking = true

	if sprite:
		sprite.modulate = Color.ORANGE
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(sprite):
			sprite.modulate = Color.WHITE

	player.take_damage(melee_damage, global_position)
	is_attacking = false

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
	# Simple flash effect
	if sprite:
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(sprite):
			sprite.modulate = Color.WHITE

func update_health_bar():
	if health_bar and health_bar is ProgressBar:
		health_bar.max_value = max_health
		health_bar.value = current_health

func die():
	# Death effect
	var death_effect = Node2D.new()
	death_effect.global_position = global_position
	
	var script = GDScript.new()
	script.source_code = """
extends Node2D
var radius = 10.0
var alpha = 1.0
func _process(delta):
	radius += 100 * delta
	alpha -= 2.0 * delta
	if alpha <= 0:
		queue_free()
	queue_redraw()
func _draw():
	var c = Color.RED
	c.a = alpha
	draw_circle(Vector2.ZERO, radius, c)
"""
	script.reload()
	death_effect.set_script(script)
	get_tree().root.add_child(death_effect)
	
	queue_free()

func _draw():
	# Debug - show attack range
	if player and global_position.distance_to(player.global_position) < detection_range:
		draw_circle(Vector2.ZERO, attack_range, Color(1, 0, 0, 0.2))
