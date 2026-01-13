extends Area2D

@export var speed: float = 600.0  # Reduced from 800 for better visibility
@export var damage: int = 1
@export var lifetime: float = 3.0
@export var bullet_color: Color = Color.YELLOW
@export var bullet_length: float = 20.0  # Increased from 12
@export var bullet_width: float = 6.0    # Increased from 3
@export var trail_enabled: bool = true
@export var trail_length: float = 30.0  # How long the trail is
@export var trail_width: float = 3.0    # How thick the trail is
@export var trail_color: Color = Color.YELLOW  # Trail color

var direction: Vector2 = Vector2.RIGHT
var shooter = null  # Reference to who shot this bullet
var has_left_shooter: bool = false  # Track if bullet has left the shooter

func _ready():
	# Add trail effect
	if trail_enabled:
		var trail = Line2D.new()
		trail.width = trail_width
		trail.default_color = trail_color
		trail.add_point(Vector2.ZERO)
		trail.add_point(Vector2(-trail_length, 0))  # Trail behind bullet
		add_child(trail)
	
	# Auto-destroy after lifetime expires
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _draw():
	# Draw bullet as a rectangle pointing RIGHT (along positive X-axis)
	# The player script will rotate the entire node
	draw_rect(Rect2(-bullet_length/2, -bullet_width/2, bullet_length, bullet_width), bullet_color)
	# Add a bright white core
	draw_rect(Rect2(-bullet_length/2, -bullet_width/4, bullet_length, bullet_width/2), Color.WHITE)
	# Optional: Add a pointed tip to show direction clearly
	var tip_points = PackedVector2Array([
		Vector2(bullet_length/2, 0),           # Tip point
		Vector2(bullet_length/2 - 5, -bullet_width/2),  # Top back
		Vector2(bullet_length/2 - 5, bullet_width/2)    # Bottom back
	])
	draw_colored_polygon(tip_points, Color.WHITE)

func _physics_process(delta):
	var movement = direction * speed * delta
	position += movement
	
	# Check if bullet has moved far enough from shooter
	if shooter and not has_left_shooter:
		var distance = global_position.distance_to(shooter.global_position)
		if distance > 50:  # 50 pixels away from shooter
			has_left_shooter = true

func _on_body_entered(body):
	# Ignore the shooter until bullet has left their area
	if shooter and body == shooter and not has_left_shooter:
		return
	
	print("Bullet hit: ", body.name)
	
	# Check if we hit an enemy or wall
	if body.is_in_group("enemies"):
		# Deal damage to enemy
		if body.has_method("take_damage"):
			body.take_damage(damage)
	
	# Destroy projectile on collision
	queue_free()

func _on_area_entered(area):
	# Ignore shooter's areas initially
	if not has_left_shooter and shooter:
		# Check if this area belongs to the shooter
		if area.get_parent() == shooter:
			return
	
	# Handle collision with other areas
	queue_free()
