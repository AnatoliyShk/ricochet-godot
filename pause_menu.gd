extends CanvasLayer

const RESOLUTIONS = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var _main_view: Control
var _options_view: Control
var _res_buttons: Array[Button] = []
var _fs_button: Button
var _cur_res_label: Label

func _ready():
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	hide()


func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		get_viewport().set_input_as_handled()
		if visible:
			_resume()
		else:
			_open()


func _open():
	_show_main()
	show()
	get_tree().paused = true


func _resume():
	hide()
	get_tree().paused = false


func _restart():
	get_tree().paused = false
	get_tree().reload_current_scene()


func _show_main():
	_main_view.show()
	_options_view.hide()


func _show_options():
	_main_view.hide()
	_options_view.show()
	_refresh_res_state()


func _exit():
	get_tree().quit()


func _set_resolution(res: Vector2i):
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(res)
	var screen := DisplayServer.screen_get_size()
	DisplayServer.window_set_position((screen - res) / 2)
	_refresh_res_state()


func _toggle_fullscreen():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_refresh_res_state()


func _refresh_res_state():
	var cur_size := DisplayServer.window_get_size()
	var is_fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

	for i in _res_buttons.size():
		_set_active(_res_buttons[i], not is_fs and RESOLUTIONS[i] == cur_size)

	if _fs_button:
		_fs_button.text = "FULLSCREEN  [ ON ]" if is_fs else "FULLSCREEN  [ OFF ]"
		_set_active(_fs_button, is_fs)

	if _cur_res_label:
		var mode_text := "Fullscreen" if is_fs else "Windowed"
		_cur_res_label.text = "%d x %d  —  %s" % [cur_size.x, cur_size.y, mode_text]


# ── Build ──────────────────────────────────────────────────────────────────────

func _build():
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.78)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(center)

	_main_view = _build_main()
	center.add_child(_main_view)

	_options_view = _build_options()
	center.add_child(_options_view)
	_options_view.hide()


func _build_main() -> Control:
	var panel := _make_panel()
	var vbox := _panel_vbox(panel)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.18, 0.18))
	title.add_theme_font_size_override("font_size", 38)
	vbox.add_child(title)

	vbox.add_child(_make_divider())

	var resume := _make_button("RESUME")
	resume.pressed.connect(_resume)
	vbox.add_child(resume)

	var restart := _make_button("RESTART")
	restart.pressed.connect(_restart)
	vbox.add_child(restart)

	var options := _make_button("OPTIONS")
	options.pressed.connect(_show_options)
	vbox.add_child(options)

	var exit := _make_button("EXIT")
	exit.pressed.connect(_exit)
	vbox.add_child(exit)

	return panel


func _build_options() -> Control:
	var panel := _make_panel()
	var vbox := _panel_vbox(panel)

	var title := Label.new()
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.18, 0.18))
	title.add_theme_font_size_override("font_size", 38)
	vbox.add_child(title)

	vbox.add_child(_make_divider())

	var res_label := Label.new()
	res_label.text = "RESOLUTION"
	res_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res_label.add_theme_color_override("font_color", Color(0.7, 0.2, 0.2))
	res_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(res_label)

	_res_buttons.clear()
	for res in RESOLUTIONS:
		var btn := _make_button("%d  ×  %d" % [res.x, res.y])
		btn.pressed.connect(_set_resolution.bind(res))
		vbox.add_child(btn)
		_res_buttons.append(btn)

	vbox.add_child(_make_spacer(6))

	_fs_button = _make_button("FULLSCREEN  [ OFF ]")
	_fs_button.pressed.connect(_toggle_fullscreen)
	vbox.add_child(_fs_button)

	vbox.add_child(_make_spacer(2))

	_cur_res_label = Label.new()
	_cur_res_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cur_res_label.add_theme_color_override("font_color", Color(0.55, 0.18, 0.18))
	_cur_res_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_cur_res_label)

	vbox.add_child(_make_divider())

	var back := _make_button("BACK")
	back.pressed.connect(_show_main)
	vbox.add_child(back)

	return panel


# ── Helpers ────────────────────────────────────────────────────────────────────

func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.0, 0.02, 0.95)
	style.set_border_width_all(3)
	style.border_color = Color(0.85, 0.12, 0.12, 1.0)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _panel_vbox(panel: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 36)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	return vbox


func _make_button(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(260, 46)
	btn.add_theme_color_override("font_color", Color(1.0, 0.28, 0.28))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.5, 0.5))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.6, 0.6))
	btn.add_theme_font_size_override("font_size", 20)

	var normal := _btn_style(Color(0.07, 0.0, 0.02, 0.9), Color(0.55, 0.08, 0.08))
	var hover  := _btn_style(Color(0.18, 0.02, 0.03, 1.0), Color(1.0, 0.18, 0.18))
	var press  := _btn_style(Color(0.28, 0.04, 0.04, 1.0), Color(1.0, 0.25, 0.25))

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", press)
	btn.add_theme_stylebox_override("focus", normal)
	return btn


func _btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(2)
	s.border_color = border
	s.set_corner_radius_all(6)
	return s


func _set_active(btn: Button, active: bool):
	var border := Color(1.0, 0.5, 0.1) if active else Color(0.55, 0.08, 0.08)
	var bg     := Color(0.22, 0.06, 0.0, 1.0) if active else Color(0.07, 0.0, 0.02, 0.9)
	btn.add_theme_stylebox_override("normal", _btn_style(bg, border))


func _make_divider() -> HSeparator:
	var sep := HSeparator.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.5, 0.08, 0.08, 0.6)
	style.content_margin_top = 2.0
	sep.add_theme_stylebox_override("separator", style)
	return sep


func _make_spacer(height: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	return s
