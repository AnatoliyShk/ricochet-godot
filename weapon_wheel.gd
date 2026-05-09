extends Node2D

const RADIUS := 210.0

var current_weapon: String = "gun"
var hovered_weapon: String = "gun"
var player_ref: Node = null

func _process(_delta: float) -> void:
	var center := get_viewport().get_visible_rect().size / 2.0
	global_position = center
	var m := get_viewport().get_mouse_position() - center
	if m.length() <= RADIUS:
		hovered_weapon = "gun" if m.x < 0.0 else "shield"
	queue_redraw()


func _draw() -> void:
	var r := RADIUS
	var font := ThemeDB.fallback_font

	# Background circle
	draw_circle(Vector2.ZERO, r, Color(0.05, 0.05, 0.09, 0.95))

	# Highlighted half (fan polygon)
	_draw_half(r, PI / 2.0, 3.0 * PI / 2.0,
		Color(0.9, 0.75, 0.1, 0.22 if hovered_weapon == "gun" else 0.07))
	_draw_half(r, -PI / 2.0, PI / 2.0,
		Color(0.5, 0.85, 1.0, 0.22 if hovered_weapon == "shield" else 0.07))

	# Outer ring
	var ring_col := Color(0.9, 0.75, 0.1) if hovered_weapon == "gun" \
		else Color(0.5, 0.85, 1.0)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, ring_col, 3.0)

	# Divider
	draw_line(Vector2(0.0, -r * 0.88), Vector2(0.0, r * 0.88),
		Color(0.3, 0.3, 0.4, 0.65), 2.0)

	# Centre dot
	draw_circle(Vector2.ZERO, 10.0, Color(0.12, 0.12, 0.18))
	draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 24, Color(0.45, 0.45, 0.55), 1.5)

	# GUN side (left, centre at x = -105)
	var g_bright := hovered_weapon == "gun"
	var g_col := Color(1.0, 0.92, 0.25) if g_bright else Color(0.7, 0.6, 0.2, 0.6)
	draw_string(font, Vector2(-175.0, 5.0),  "GUN",
		HORIZONTAL_ALIGNMENT_CENTER, 140, 52, g_col)
	draw_string(font, Vector2(-175.0, 58.0), "primary",
		HORIZONTAL_ALIGNMENT_CENTER, 140, 16, Color(g_col.r, g_col.g, g_col.b, 0.55))
	if current_weapon == "gun":
		draw_string(font, Vector2(-175.0, 82.0), "EQUIPPED",
			HORIZONTAL_ALIGNMENT_CENTER, 140, 13, Color(0.9, 0.75, 0.1, 0.75))

	# SHIELD side (right, centre at x = 105)
	var s_bright := hovered_weapon == "shield"
	var s_col := Color(0.65, 0.92, 1.0) if s_bright else Color(0.4, 0.65, 0.8, 0.6)
	draw_string(font, Vector2(35.0, 5.0),  "SHIELD",
		HORIZONTAL_ALIGNMENT_CENTER, 140, 40, s_col)
	draw_string(font, Vector2(35.0, 58.0), "deflects 90°",
		HORIZONTAL_ALIGNMENT_CENTER, 140, 16, Color(s_col.r, s_col.g, s_col.b, 0.55))
	if current_weapon == "shield":
		draw_string(font, Vector2(35.0, 82.0), "EQUIPPED",
			HORIZONTAL_ALIGNMENT_CENTER, 140, 13, Color(0.5, 0.85, 1.0, 0.75))

	# Hint at top
	draw_string(font, Vector2(-150.0, -r + 42.0),
		"Release Tab to confirm  •  Click to select",
		HORIZONTAL_ALIGNMENT_CENTER, 300, 13, Color(0.55, 0.55, 0.55, 0.8))


func _draw_half(r: float, a_from: float, a_to: float, color: Color) -> void:
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in 33:
		var a := a_from + (a_to - a_from) * float(i) / 32.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, color)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var m := get_viewport().get_mouse_position() - get_viewport().get_visible_rect().size / 2.0
	if m.length() <= RADIUS and player_ref:
		get_viewport().set_input_as_handled()
		player_ref._wheel_hovered = hovered_weapon
		player_ref._hide_weapon_wheel()
