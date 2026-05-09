extends Node2D

var spray_dir: Vector2 = Vector2.ZERO
var _lifetime: float = 5.0
var _elapsed: float = 0.0
var _drops: Array = []  # {pos, radius, angle, stretch, hue}

func _ready():
	var count = randi_range(16, 26)
	for i in count:
		var use_spray = spray_dir.length() > 0.1 and randf() < 0.65
		var pos: Vector2
		var angle: float
		var radius: float
		var stretch: float

		if use_spray:
			var spread = randf_range(-1.0, 1.0)
			var dir = spray_dir.rotated(spread)
			var dist = randf_range(6, 40)
			pos = dir * dist
			angle = dir.angle()
			radius = randf_range(2.0, 5.0)
			stretch = randf_range(1.8, 4.5)
		else:
			var a = randf() * TAU
			pos = Vector2(cos(a), sin(a)) * randf_range(0, 20)
			angle = a
			radius = randf_range(3.0, 9.0)
			stretch = 1.0

		_drops.append({
			"pos": pos, "radius": radius,
			"angle": angle, "stretch": stretch,
			"hue": randf_range(0.5, 0.75),
		})

func _process(delta):
	_elapsed += delta
	if _elapsed >= _lifetime:
		queue_free()
		return
	queue_redraw()

func _draw():
	var alpha = pow(1.0 - _elapsed / _lifetime, 0.35)
	for d in _drops:
		var c = Color(d.hue, 0.0, 0.0, alpha)
		if d.stretch > 1.2:
			draw_set_transform(d.pos, d.angle, Vector2(d.stretch, 1.0))
			draw_circle(Vector2.ZERO, d.radius, c)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_circle(d.pos, d.radius, c)
