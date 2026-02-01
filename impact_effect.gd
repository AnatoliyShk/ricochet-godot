extends Node2D

@export var impact_color: Color = Color.WHITE
@export var initial_radius: float = 15.0
@export var fade_speed: float = 3.0
@export var expand_speed: float = 50.0

var current_radius: float = 5.0
var alpha: float = 1.0

func _ready():
	current_radius = initial_radius

func _process(delta):
	# Expand the circle
	current_radius += expand_speed * delta
	
	# Fade out
	alpha -= fade_speed * delta
	
	# Remove when fully faded
	if alpha <= 0:
		queue_free()
	
	queue_redraw()

func _draw():
	# Draw expanding circle with fade
	var color = impact_color
	color.a = alpha
	draw_circle(Vector2.ZERO, current_radius, color)
	
	# Optional: Draw a smaller bright core
	if alpha > 0.5:
		var core_color = Color.WHITE
		core_color.a = alpha
		draw_circle(Vector2.ZERO, current_radius * 0.3, core_color)
