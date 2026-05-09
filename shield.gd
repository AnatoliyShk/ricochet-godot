extends StaticBody2D

func _ready():
	add_to_group("walls")
	add_to_group("shield")

func _draw():
	draw_rect(Rect2(-7.5, -37.5, 15.0, 75.0), Color.WHITE)
	draw_rect(Rect2(-9.5, -39.5, 19.0, 79.0), Color(0.6, 0.9, 1.0, 0.22))
