extends CanvasLayer

const _DOS_FONT = preload("res://Perfect DOS VGA 437.ttf")

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
var _music_vol_label: Label = null
var _immortal_btn: Button = null
var _music_volume_pct: int = 100

var _crt_material: ShaderMaterial = null
var _tv_tween: Tween = null

func _ready():
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	hide()
	var crt_node = get_parent().get_node_or_null("CanvasLayer2/CRTEffect")
	if crt_node and crt_node.material is ShaderMaterial:
		_crt_material = crt_node.material


func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		get_viewport().set_input_as_handled()
		if visible:
			_resume()
		else:
			_open()


func _open():
	_show_main()
	get_tree().paused = true
	if _crt_material:
		_crt_material.set_shader_parameter("tv_off", 0.0)
		if _tv_tween:
			_tv_tween.kill()
		_tv_tween = create_tween()
		_tv_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_tv_tween.tween_method(
			func(v: float): _crt_material.set_shader_parameter("tv_off", v),
			0.0, 1.0, 0.55
		)
		_tv_tween.tween_callback(show)
	else:
		show()


func _resume():
	hide()
	if _crt_material:
		if _tv_tween:
			_tv_tween.kill()
		_tv_tween = create_tween()
		_tv_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_tv_tween.tween_method(
			func(v: float): _crt_material.set_shader_parameter("tv_off", v),
			1.0, 0.0, 0.55
		)
		_tv_tween.tween_callback(func(): get_tree().paused = false)
	else:
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
	_refresh_immortal_btn()


# ── Build ──────────────────────────────────────────────────────────────────────

func _build():
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
	title.add_theme_font_override("font", _DOS_FONT)
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
	title.add_theme_font_override("font", _DOS_FONT)
	title.add_theme_color_override("font_color", Color(1.0, 0.18, 0.18))
	title.add_theme_font_size_override("font_size", 38)
	vbox.add_child(title)

	vbox.add_child(_make_divider())

	var res_label := Label.new()
	res_label.text = "RESOLUTION"
	res_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res_label.add_theme_font_override("font", _DOS_FONT)
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
	_cur_res_label.add_theme_font_override("font", _DOS_FONT)
	_cur_res_label.add_theme_color_override("font_color", Color(0.55, 0.18, 0.18))
	_cur_res_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_cur_res_label)

	vbox.add_child(_make_spacer(6))

	var vol_row := HBoxContainer.new()
	vol_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vol_row.add_theme_constant_override("separation", 8)

	var vol_down := _make_small_btn("◄")
	vol_down.pressed.connect(func(): _change_music_volume(-10))
	vol_row.add_child(vol_down)

	_music_vol_label = Label.new()
	_music_vol_label.text = "MUSIC  100%"
	_music_vol_label.custom_minimum_size = Vector2(140, 0)
	_music_vol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_music_vol_label.add_theme_font_override("font", _DOS_FONT)
	_music_vol_label.add_theme_color_override("font_color", Color(0.7, 0.2, 0.2))
	_music_vol_label.add_theme_font_size_override("font_size", 16)
	vol_row.add_child(_music_vol_label)

	var vol_up := _make_small_btn("►")
	vol_up.pressed.connect(func(): _change_music_volume(10))
	vol_row.add_child(vol_up)

	vbox.add_child(vol_row)

	vbox.add_child(_make_spacer(4))

	_immortal_btn = _make_button("IMMORTAL  [ OFF ]")
	_immortal_btn.pressed.connect(_toggle_immortal)
	vbox.add_child(_immortal_btn)

	vbox.add_child(_make_divider())

	var back := _make_button("BACK")
	back.pressed.connect(_show_main)
	vbox.add_child(back)

	return panel


func _change_music_volume(delta: int) -> void:
	_music_volume_pct = clampi(_music_volume_pct + delta, 0, 100)
	if _music_vol_label:
		_music_vol_label.text = "MUSIC  %d%%" % _music_volume_pct
	var music = get_tree().get_first_node_in_group("music")
	if music:
		var db := -80.0 if _music_volume_pct == 0 \
			else linear_to_db(float(_music_volume_pct) / 100.0)
		music.volume_db = db
		music.set_meta("base_volume_db", db)
	_play_ui_click()


func _toggle_immortal() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and "is_immortal" in player:
		player.is_immortal = !player.is_immortal
	_refresh_immortal_btn()


func _refresh_immortal_btn() -> void:
	if not _immortal_btn:
		return
	var player = get_tree().get_first_node_in_group("player")
	var on: bool = player != null and "is_immortal" in player and player.is_immortal
	_immortal_btn.text = "IMMORTAL  [ ON ]" if on else "IMMORTAL  [ OFF ]"
	_set_active(_immortal_btn, on)


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


func _play_ui_click() -> void:
	var p := AudioStreamPlayer.new()
	p.stream = load("res://Audio/UI/uI_success_sound_1.mp3")
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _make_button(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(260, 46)
	btn.add_theme_color_override("font_color", Color(1.0, 0.28, 0.28))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.5, 0.5))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.6, 0.6))
	btn.add_theme_font_override("font", _DOS_FONT)
	btn.add_theme_font_size_override("font_size", 20)

	var normal := _btn_style(Color(0.07, 0.0, 0.02, 0.9), Color(0.55, 0.08, 0.08))
	var hover  := _btn_style(Color(0.18, 0.02, 0.03, 1.0), Color(1.0, 0.18, 0.18))
	var press  := _btn_style(Color(0.28, 0.04, 0.04, 1.0), Color(1.0, 0.25, 0.25))

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", press)
	btn.add_theme_stylebox_override("focus", normal)
	btn.pressed.connect(_play_ui_click)
	return btn


func _make_small_btn(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(46, 36)
	btn.add_theme_color_override("font_color", Color(1.0, 0.28, 0.28))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.5, 0.5))
	btn.add_theme_font_override("font", _DOS_FONT)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_stylebox_override("normal", _btn_style(Color(0.07, 0.0, 0.02, 0.9), Color(0.55, 0.08, 0.08)))
	btn.add_theme_stylebox_override("hover",  _btn_style(Color(0.18, 0.02, 0.03, 1.0), Color(1.0, 0.18, 0.18)))
	btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.28, 0.04, 0.04, 1.0), Color(1.0, 0.25, 0.25)))
	btn.add_theme_stylebox_override("focus", _btn_style(Color(0.07, 0.0, 0.02, 0.9), Color(0.55, 0.08, 0.08)))
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
