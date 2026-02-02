extends CharacterBody2D

@export var max_health: int = 3
@export var move_speed: float = 150.0
@export var shoot_interval: float = 2.0  # Seconds between shots
@export var projectile_scene: PackedScene
@export var detection_range: float = 800.0
@export var shoot_range: float = 600.0

var current_health: int
var shoot_timer: float = 0.0
var player: Node2D = null

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
	
	# Move towards player if in detection range
	if distance_to_player < detection_range and distance_to_player > 200:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * move_speed
		move_and_slide()
		
		# Flip sprite based on direction
		if sprite and direction.x != 0:
			sprite.flip_h = direction.x < 0
	else:
		velocity = Vector2.ZERO
	
	# Shoot at player
	shoot_timer -= delta
	if shoot_timer <= 0 and distance_to_player < shoot_range:
		shoot_at_player()
		shoot_timer = shoot_interval

func shoot_at_player():
	if not projectile_scene or not player:
		return
	
	print("Enemy shooting at player!")
	
	# Create projectile
	var projectile = projectile_scene.instantiate()
	
	# Set direction towards player
	var direction = (player.global_position - global_position).normalized()
	projectile.direction = direction
	projectile.rotation = direction.angle()
	projectile.global_position = global_position
	projectile.shooter = self
	
	# Make enemy bullets different color (red)
	projectile.bullet_color = Color.RED
	projectile.trail_color = Color.RED
	
	# Add to scene
	get_tree().root.add_child(projectile)

func take_damage(amount: int):
	current_health -= amount
	print("Enemy took ", amount, " damage! Health: ", current_health, "/", max_health)
	
	# Flash effect
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
	print("Enemy died!")
	
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
