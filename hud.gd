extends CanvasLayer

var _hearts_container: HBoxContainer
var _heart_labels: Array = []
var _current_max_hp: int = 0
var _current_hp: int = 0
var _pulse_tween: Tween

var _bullets_container: HBoxContainer
var _bullet_styles: Array = []
var _bullet_panels: Array = []
var _current_max_ammo: int = 0
var _last_ammo: int = -1

func _ready():
	add_to_group("hud")
	_build()


func _build():
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)
	vbox.add_child(_build_hp_panel())
	vbox.add_child(_build_ammo_panel())


func _build_hp_panel() -> PanelContainer:
	var panel = PanelContainer.new()

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.0, 0.02, 0.92)
	panel_style.set_border_width_all(3)
	panel_style.border_color = Color(0.9, 0.12, 0.12, 1.0)
	panel_style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	_hearts_container = HBoxContainer.new()
	_hearts_container.add_theme_constant_override("separation", 4)
	margin.add_child(_hearts_container)

	return panel


func _build_heart_icons(count: int):
	for child in _hearts_container.get_children():
		child.queue_free()
	_heart_labels.clear()
	_current_max_hp = count

	for i in count:
		var label = Label.new()
		label.text = "♥"
		label.add_theme_font_size_override("font_size", 28)
		label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15))
		_heart_labels.append(label)
		_hearts_container.add_child(label)


func _build_ammo_panel() -> PanelContainer:
	var panel = PanelContainer.new()

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.03, 0.0, 0.92)
	panel_style.set_border_width_all(3)
	panel_style.border_color = Color(0.9, 0.75, 0.1, 1.0)
	panel_style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	margin.add_child(hbox)

	_bullets_container = HBoxContainer.new()
	_bullets_container.add_theme_constant_override("separation", 6)
	_bullets_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(_bullets_container)

	return panel


func _build_bullet_icons(count: int):
	for child in _bullets_container.get_children():
		child.queue_free()
	_bullet_styles.clear()
	_bullet_panels.clear()
	_current_max_ammo = count

	for i in count:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1.0, 0.88, 0.15)
		style.set_border_width_all(2)
		style.border_color = Color(0.75, 0.6, 0.05)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 2
		style.corner_radius_bottom_right = 2

		var bullet = Panel.new()
		bullet.custom_minimum_size = Vector2(12, 28)
		bullet.add_theme_stylebox_override("panel", style)

		_bullet_styles.append(style)
		_bullet_panels.append(bullet)
		_bullets_container.add_child(bullet)


func _eject_shell(index: int):
	if index < 0 or index >= _bullet_panels.size():
		return
	var source: Panel = _bullet_panels[index]
	await get_tree().process_frame

	var start_pos = source.get_global_rect().position

	var shell = Panel.new()
	shell.size = Vector2(12, 28)
	shell.position = start_pos

	var style = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.88, 0.15)
	style.set_border_width_all(2)
	style.border_color = Color(0.75, 0.6, 0.05)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	shell.add_theme_stylebox_override("panel", style)

	add_child(shell)

	var duration := randf_range(0.35, 0.5)
	var end_pos: Vector2 = start_pos + Vector2(randf_range(18, 38), randf_range(-55, -80))
	var end_rot: float = randf_range(0.6, 1.4)

	var tween = create_tween().set_parallel(true)
	tween.tween_property(shell, "position", end_pos, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(shell, "rotation", end_rot, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(shell, "modulate:a", 0.0, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(shell.queue_free)


func set_health(current: int, max_val: int):
	if max_val != _current_max_hp:
		_build_heart_icons(max_val)
	_current_hp = current

	for i in _current_max_hp:
		if i < current:
			_heart_labels[i].add_theme_color_override("font_color", Color(1.0, 0.15, 0.15))
			_heart_labels[i].modulate.a = 1.0
		else:
			_heart_labels[i].add_theme_color_override("font_color", Color(0.25, 0.05, 0.05))
			_heart_labels[i].modulate.a = 0.4

	if current <= 1:
		_start_pulse()
	else:
		_stop_pulse()


func set_ammo(current: int, max_val: int):
	if max_val != _current_max_ammo:
		_build_bullet_icons(max_val)

	var shot_fired := _last_ammo > 0 and current < _last_ammo

	for i in _current_max_ammo:
		if i < current:
			_bullet_styles[i].bg_color = Color(1.0, 0.88, 0.15)
			_bullet_styles[i].border_color = Color(0.75, 0.6, 0.05)
		else:
			_bullet_styles[i].bg_color = Color(0.12, 0.10, 0.03, 0.7)
			_bullet_styles[i].border_color = Color(0.12, 0.10, 0.02, 0.4)

	if shot_fired:
		_eject_shell(current)

	_last_ammo = current


func set_reload_progress(progress: float):
	var lit_count = int(progress * _current_max_ammo)
	for i in _current_max_ammo:
		if i < lit_count:
			_bullet_styles[i].bg_color = Color(0.9, 0.55, 0.1)
			_bullet_styles[i].border_color = Color(0.7, 0.4, 0.05)
		else:
			_bullet_styles[i].bg_color = Color(0.12, 0.10, 0.03, 0.7)
			_bullet_styles[i].border_color = Color(0.12, 0.10, 0.02, 0.4)


func _start_pulse():
	if _pulse_tween and _pulse_tween.is_running():
		return
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_method(_set_active_heart_color, Color(1.0, 0.15, 0.15), Color(1.0, 0.6, 0.0), 0.35)
	_pulse_tween.tween_method(_set_active_heart_color, Color(1.0, 0.6, 0.0), Color(1.0, 0.15, 0.15), 0.35)


func _stop_pulse():
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	_set_active_heart_color(Color(1.0, 0.15, 0.15))


func _set_active_heart_color(color: Color):
	for i in _current_max_hp:
		if i < _current_hp:
			_heart_labels[i].add_theme_color_override("font_color", color)
