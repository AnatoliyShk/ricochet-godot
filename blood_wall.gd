extends Node2D

var _lifetime: float = 9.0
var _elapsed: float = 0.0
var _drops: Array = []

func _ready():
	var count = randi_range(10, 16)
	for i in count:
		var a = randf() * TAU
		var dist = randf_range(0, 14)
		var radius = randf_range(2.5, 8.0)
		# Some drops have a downward drip tail
		var drip = randf_range(0, 18) if randf() < 0.4 else 0.0
		_drops.append({
			"pos": Vector2(cos(a), sin(a)) * dist,
			"radius": radius,
			"drip": drip,
			"hue": randf_range(0.45, 0.68),
		})

func _process(delta):
	_elapsed += delta
	if _elapsed >= _lifetime:
		queue_free()
		return
	queue_redraw()

func _draw():
	var alpha = pow(1.0 - _elapsed / _lifetime, 0.28)
	for d in _drops:
		var c = Color(d.hue, 0.0, 0.0, alpha)
		draw_circle(d.pos, d.radius, c)
		if d.drip > 0:
			# Drip streak downward
			draw_set_transform(d.pos + Vector2(0, d.drip * 0.5), 0.0, Vector2(1.0, 1.0))
			draw_rect(
				Rect2(-d.radius * 0.4, 0, d.radius * 0.8, d.drip),
				c
			)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
