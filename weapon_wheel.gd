extends Node2D

const RADIUS  := 210.0
const INNER_R := RADIUS * 0.42   # inner hole of the donut

const WEAPONS: Array[String] = ["gun", "shotgun", "laser", "revolver", "shield"]
const ICONS:   Array[String] = ["⊕", "✦", "⚡", "◉", "▣"]
const COLORS: Array[Color] = [
	Color(1.0, 0.92, 0.25),
	Color(1.0, 0.50, 0.10),
	Color(0.20, 1.0, 0.40),
	Color(0.85, 0.25, 1.0),
	Color(0.50, 0.85, 1.0),
]
const ANGLES: Array[float] = [
	-PI / 2.0,
	-PI / 2.0 + 2.0 * PI / 5.0,
	-PI / 2.0 + 4.0 * PI / 5.0,
	-PI / 2.0 + 6.0 * PI / 5.0,
	-PI / 2.0 + 8.0 * PI / 5.0,
]

var current_weapon: String = "gun"
var hovered_weapon: String = "gun"
var player_ref: Node = null

var _rifle_tex: Texture2D = null

func _ready() -> void:
	_rifle_tex = load("res://player/riffle.png") as Texture2D


func _process(_delta: float) -> void:
	var center := get_viewport().get_visible_rect().size / 2.0
	global_position = center
	var m := get_viewport().get_mouse_position() - center
	if m.length() > INNER_R:
		var best_idx := 0
		var best_dot := -INF
		for i in WEAPONS.size():
			var weapon_dir := Vector2(cos(ANGLES[i]), sin(ANGLES[i]))
			var dot := m.normalized().dot(weapon_dir)
			if dot > best_dot:
				best_dot = dot
				best_idx = i
		hovered_weapon = WEAPONS[best_idx]
	queue_redraw()


func _draw() -> void:
	var r     := RADIUS
	var ir    := INNER_R
	var font  := ThemeDB.fallback_font
	var half  := PI / 5.0   # 36° half-sector

	# Ring sectors
	for i in WEAPONS.size():
		var c     := COLORS[i]
		var alpha := 0.30 if hovered_weapon == WEAPONS[i] else 0.09
		_draw_ring_sector(r, ir, ANGLES[i] - half, ANGLES[i] + half, Color(c.r, c.g, c.b, alpha))

	# Outer border — color of hovered weapon
	var ri       := WEAPONS.find(hovered_weapon)
	var ring_col := COLORS[ri] if ri >= 0 else Color.WHITE
	draw_arc(Vector2.ZERO, r,  0.0, TAU, 72, ring_col, 3.0)

	# Inner border
	draw_arc(Vector2.ZERO, ir, 0.0, TAU, 48, Color(0.3, 0.3, 0.45, 0.7), 1.5)

	# Dividers (only within the band)
	var div_col := Color(0.3, 0.3, 0.4, 0.6)
	for i in WEAPONS.size():
		var ba := ANGLES[i] - half
		var d  := Vector2(cos(ba), sin(ba))
		draw_line(d * ir, d * r, div_col, 1.5)

	# Icons at ring midpoint
	var mid_r := (r + ir) * 0.5
	for i in WEAPONS.size():
		var hovered  := hovered_weapon == WEAPONS[i]
		var equipped := current_weapon == WEAPONS[i]
		var col      := COLORS[i]
		var draw_col := col if hovered else Color(col.r, col.g, col.b, 0.55)

		var icon_center := Vector2(cos(ANGLES[i]), sin(ANGLES[i])) * mid_r
		var icon_size   := 44 if hovered else 32

		# Glow halo for hovered
		if hovered:
			draw_arc(icon_center, 28.0, 0.0, TAU, 32, Color(col.r, col.g, col.b, 0.25), 8.0)

		# Equipped dot below icon
		if equipped:
			draw_circle(icon_center + Vector2(0, 22), 4.0, col)

		# Icon
		if WEAPONS[i] == "gun" and _rifle_tex:
			var sz: float = float(icon_size) * 1.1
			var rect := Rect2(icon_center - Vector2(sz, sz) * 0.5, Vector2(sz, sz))
			draw_texture_rect(_rifle_tex, rect, false, draw_col)
		else:
			var art: Array = COMPACT_ICONS.get(WEAPONS[i], ["?"])
			var fsize := 10
			var lh    := fsize + 2
			var total_h := art.size() * lh
			var start_y := icon_center.y - total_h * 0.5 + fsize
			for li in art.size():
				var lw := font.get_string_size(art[li], HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
				draw_string(font, Vector2(icon_center.x - lw * 0.5, start_y + li * lh),
					art[li], HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, draw_col)

	# Hint
	draw_string(font, Vector2(-130.0, -r + 36.0),
		"Tab: confirm   Click: select",
		HORIZONTAL_ALIGNMENT_CENTER, 260, 12, Color(0.5, 0.5, 0.5, 0.75))


func _draw_ring_sector(r_outer: float, r_inner: float,
		a_from: float, a_to: float, color: Color) -> void:
	var steps := 14
	var pts   := PackedVector2Array()
	for i in steps + 1:
		var a := a_from + (a_to - a_from) * float(i) / float(steps)
		pts.append(Vector2(cos(a), sin(a)) * r_outer)
	for i in steps + 1:
		var a := a_to - (a_to - a_from) * float(i) / float(steps)
		pts.append(Vector2(cos(a), sin(a)) * r_inner)
	draw_colored_polygon(pts, color)


const COMPACT_ICONS: Dictionary = {
	"gun": [
		" _   ___________",
		"[#|_/ ___ ___ __)-",
		"  |  [__][__] /",
		"  |_/\\_]    /_]",
	],
	"shotgun": [
		" ____________________",
		"/ _______ __________ \\",
		"/_/     || [_][_][_]\\_|",
		"_ ____  |_|",
		"\\_]  \\_]",
	],
	"laser": [
		" _______________________",
		"/| == || == || ________  |",
		"/_|____||____||_/\\______/ |",
		"__|          |         |_/",
		"  | /\\_______|",
		"  |__/",
	],
	"revolver": [
		"  ___________",
		" _/_ _ ______|",
		"/ / (_)(_)___)",
		"/ /  [____]",
		"/_/ ___________",
		"   _/_ _ ______|",
		"  / / (_)(_)___)",
		"  / /  [____]",
		" /_/",
	],
	"shield": [
		"  .---.",
		" / .-. \\",
		"| | O | |",
		" \\ `-' /",
		"  `---'",
	],
}


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var m := get_viewport().get_mouse_position() - get_viewport().get_visible_rect().size / 2.0
	var dist := m.length()
	if dist >= INNER_R and dist <= RADIUS and player_ref:
		get_viewport().set_input_as_handled()
		var p := AudioStreamPlayer.new()
		p.stream = load("res://Audio/UI/uI_success_sound_1.mp3")
		get_tree().root.add_child(p)
		p.play()
		p.finished.connect(p.queue_free)
		player_ref._wheel_hovered = hovered_weapon
		player_ref._hide_weapon_wheel()
