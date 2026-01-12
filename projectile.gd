extends Area2D

@export var speed: float = 800.0
@export var damage: int = 1
@export var lifetime: float = 3.0
@export var bullet_color: Color = Color.YELLOW
@export var bullet_length: float = 12.0
@export var bullet_width: float = 3.0
@export var trail_enabled: bool = true

var direction: Vector2 = Vector2.RIGHT

func _ready():
	# Add trail effect
	if trail_enabled:
		var trail = Line2D.new()
		trail.width = 2
		trail.default_color = bullet_color
		trail.add_point(Vector2.ZERO)
		trail.add_point(Vector2(-20, 0))  # Trail behind bullet
		add_child(trail)
	
	# Auto-destroy after lifetime expires
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _draw():
	# Draw bullet as a rectangle
	draw_rect(Rect2(-bullet_length/2, -bullet_width/2, bullet_length, bullet_width), bullet_color)
	# Or draw as a circle
	# draw_circle(Vector2.ZERO, bullet_width, bullet_color)

func _physics_process(delta):
	position += direction * speed * delta

func _on_body_entered(body):
	# Check if we hit an enemy or wall
	if body.is_in_group("enemies"):
		# Deal damage to enemy
		if body.has_method("take_damage"):
			body.take_damage(damage)
	
	# Destroy projectile on any collision
	queue_free()

func _on_area_entered(area):
	# Handle collision with other areas if needed
	queue_free()
