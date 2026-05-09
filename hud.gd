extends CanvasLayer

var _vbox: VBoxContainer
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

var _bouncing_shells: Array = []  # Array of {panel, vel, time_left}

var _score: int = 0
var _score_label: Label = null
var _level: int = 0
var _level_label: Label = null

var _dash_bar: ProgressBar = null
var _dash_fill_style: StyleBoxFlat = null

const LEVEL_THRESHOLDS: Array = [300, 700, 1500]

func _ready():
	add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build():
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 13)
	add_child(_vbox)
	_vbox.add_child(_build_hp_panel())
	_vbox.add_child(_build_dash_bar())

	var bottom_row = HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 16)
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_child(bottom_row)
	bottom_row.add_child(_build_ammo_panel())

	var score_vbox = VBoxContainer.new()
	score_vbox.add_theme_constant_override("separation", 0)
	score_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom_row.add_child(score_vbox)

	_level_label = Label.new()
	_level_label.text = "LVL 0"
	_level_label.add_theme_font_size_override("font_size", 14)
	_level_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.7, 0.6))
	score_vbox.add_child(_level_label)

	_score_label = Label.new()
	_score_label.text = "0"
	_score_label.add_theme_font_size_override("font_size", 64)
	_score_label.add_theme_color_override("font_color", Color.WHITE)
	score_vbox.add_child(_score_label)


func _process(delta):
	if _vbox and _vbox.size != Vector2.ZERO:
		var vp_size = get_viewport().get_visible_rect().size
		_vbox.position = Vector2(
			(vp_size.x - _vbox.size.x) * 0.5,
			vp_size.y - _vbox.size.y - 25.0
		)

	if _bouncing_shells.is_empty():
		return

	var vp = get_viewport().get_visible_rect()
	var to_remove: Array = []

	for data in _bouncing_shells:
		data.time_left -= delta
		var p: Panel = data.panel

		if data.time_left <= 0.0 or not is_instance_valid(p):
			if is_instance_valid(p):
				p.queue_free()
			to_remove.append(data)
			continue

		data.vel.y += 900.0 * delta  # gravity

		p.position += data.vel * delta

		var pw = p.size.x
		var ph = p.size.y

		if p.position.x < 0.0:
			p.position.x = 0.0
			data.vel.x = abs(data.vel.x) * 0.92
		elif p.position.x + pw > vp.size.x:
			p.position.x = vp.size.x - pw
			data.vel.x = -abs(data.vel.x) * 0.92

		if p.position.y < 0.0:
			p.position.y = 0.0
			data.vel.y = abs(data.vel.y) * 0.92
		elif p.position.y + ph > vp.size.y:
			p.position.y = vp.size.y - ph
			data.vel.y = -abs(data.vel.y) * 0.92

		p.rotation += data.vel.x * 0.002 * delta

		if data.time_left < 1.0:
			p.modulate.a = data.time_left

	for data in to_remove:
		_bouncing_shells.erase(data)


func _score_color() -> Color:
	if _score < 200:
		return Color.WHITE
	elif _score < 500:
		return Color(0.2, 1.0, 0.35)
	else:
		return Color(0.75, 0.25, 1.0)


func add_score(amount: int) -> void:
	_score += amount
	if not _score_label:
		return
	_score_label.text = str(_score)
	_score_label.add_theme_color_override("font_color", _score_color())
	var tween = create_tween()
	tween.tween_property(_score_label, "scale", Vector2(1.35, 1.35), 0.07)
	tween.tween_property(_score_label, "scale", Vector2(1.0, 1.0), 0.13)
	_check_level_up()


func _check_level_up() -> void:
	var leveled_up := false
	while _level < LEVEL_THRESHOLDS.size() and _score >= LEVEL_THRESHOLDS[_level]:
		_level += 1
		leveled_up = true
	if not leveled_up:
		return
	if _level_label:
		_level_label.text = "LVL %d" % _level
	var tween = create_tween().set_parallel(true)
	tween.tween_property(_level_label, "scale", Vector2(1.6, 1.6), 0.1)
	tween.tween_property(_level_label, "modulate", Color(1.0, 1.0, 0.3, 1.0), 0.1)
	await tween.finished
	tween = create_tween().set_parallel(true)
	tween.tween_property(_level_label, "scale", Vector2(1.0, 1.0), 0.2)
	tween.tween_property(_level_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)
	await tween.finished
	_show_upgrade_panel()


func show_score_popup(amount: int, world_pos: Vector2) -> void:
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * world_pos
	var label = Label.new()
	label.text = "+%d" % amount
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", _score_color())
	label.position = screen_pos - Vector2(40, 30)
	add_child(label)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 110.0, 2.0)
	tween.tween_property(label, "modulate:a", 0.0, 2.0)
	await tween.finished
	if is_instance_valid(label):
		label.queue_free()


func _show_upgrade_panel() -> void:
	get_tree().paused = true

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

	# Bullet layer — full overlay, drawn first so it sits behind cards and title
	var bullet_bg := Control.new()
	bullet_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bullet_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bullet_script := GDScript.new()
	bullet_script.source_code = """
extends Control
const COLORS = [Color(0.2,1.0,0.3,0.55), Color(0.3,0.6,1.0,0.55), Color(0.75,0.2,1.0,0.55), Color(1.0,0.55,0.1,0.55)]
var bullets = []
func _ready():
\tfor i in 72:
\t\tbullets.append({"p": Vector2(randf_range(0,size.x), randf_range(0,size.y)), "v": Vector2(randf_range(-1.0,1.0), randf_range(-1.0,1.0)).normalized() * randf_range(300,470), "c": COLORS[randi()%COLORS.size()]})
func _process(delta):
\tvar w = size.x; var h = size.y
\tfor b in bullets:
\t\tb.p += b.v * delta
\t\tif b.p.x < 0 or b.p.x > w: b.v.x = -b.v.x; b.c = COLORS[randi()%COLORS.size()]; b.p.x = clamp(b.p.x,0,w)
\t\tif b.p.y < 0 or b.p.y > h: b.v.y = -b.v.y; b.c = COLORS[randi()%COLORS.size()]; b.p.y = clamp(b.p.y,0,h)
\tqueue_redraw()
func _draw():
\tfor b in bullets:
\t\tvar d = b.v.normalized(); var perp = Vector2(-d.y,d.x)
\t\tdraw_colored_polygon(PackedVector2Array([b.p+d*12-perp*3,b.p+d*12+perp*3,b.p-d*12+perp*3,b.p-d*12-perp*3]), b.c)
"""
	bullet_script.reload()
	bullet_bg.set_script(bullet_script)
	overlay.add_child(bullet_bg)

	var title = Label.new()
	title.text = "LEVEL UP! — CHOOSE AN UPGRADE"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.offset_top = 60
	overlay.add_child(title)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	center.add_child(hbox)

	_add_upgrade_card(hbox, "⬡", "AMMO UP", "+2 Max Ammo",
		Color(0.9, 0.75, 0.1), overlay, "ammo")
	_add_upgrade_card(hbox, "♥", "HP UP", "+1 Max HP",
		Color(0.9, 0.12, 0.12), overlay, "hp")
	_add_upgrade_card(hbox, "✦", "FULL HEAL", "Restore All HP",
		Color(0.1, 0.85, 0.6), overlay, "heal")


func _add_upgrade_card(parent: HBoxContainer, symbol: String, title: String,
		desc: String, color: Color, overlay: ColorRect, upgrade_type: String) -> void:
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.05, 0.05, 0.08, 0.95)
	card_style.set_border_width_all(5)
	card_style.border_color = color
	card_style.set_corner_radius_all(16)

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(300, 700)
	card.add_theme_stylebox_override("panel", card_style)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	card.add_child(vbox)

	var sym = Label.new()
	sym.text = symbol
	sym.add_theme_font_size_override("font_size", 90)
	sym.add_theme_color_override("font_color", color)
	sym.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sym)

	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 38)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 22)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc_lbl)

	var hint = Label.new()
	hint.text = "CLICK TO CHOOSE"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	card.mouse_entered.connect(func():
		card_style.bg_color = Color(0.1, 0.1, 0.16, 0.98)
		card_style.border_color = Color(color.r, color.g, color.b, 1.0).lightened(0.3)
	)
	card.mouse_exited.connect(func():
		card_style.bg_color = Color(0.05, 0.05, 0.08, 0.95)
		card_style.border_color = color
	)
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			_apply_upgrade(upgrade_type)
			overlay.queue_free()
			get_tree().paused = false
	)


func _apply_upgrade(type: String) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	match type:
		"ammo":
			if player.has_method("upgrade_ammo"):
				player.upgrade_ammo()
		"hp":
			if player.has_method("upgrade_hp"):
				player.upgrade_hp()
		"heal":
			if player.has_method("upgrade_heal"):
				player.upgrade_heal()


func _build_dash_bar() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	_dash_bar = ProgressBar.new()
	_dash_bar.custom_minimum_size = Vector2(120, 5)
	_dash_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_dash_bar.max_value = 1.0
	_dash_bar.value = 1.0
	_dash_bar.show_percentage = false

	_dash_fill_style = StyleBoxFlat.new()
	_dash_fill_style.bg_color = Color(0.3, 0.85, 1.0)
	_dash_fill_style.set_corner_radius_all(2)
	_dash_bar.add_theme_stylebox_override("fill", _dash_fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.12, 0.9)
	bg_style.set_corner_radius_all(2)
	_dash_bar.add_theme_stylebox_override("background", bg_style)

	row.add_child(_dash_bar)
	return row


func set_dash(is_dashing: bool, progress: float) -> void:
	if not _dash_bar or not _dash_fill_style:
		return
	_dash_bar.value = clampf(progress, 0.0, 1.0)
	if is_dashing:
		_dash_fill_style.bg_color = Color(0.2, 1.0, 0.95)
	elif progress >= 1.0:
		_dash_fill_style.bg_color = Color(0.3, 0.85, 1.0)
	else:
		_dash_fill_style.bg_color = Color(0.1, 0.3 + 0.5 * progress, 0.5 + 0.5 * progress)


func _build_hp_panel() -> PanelContainer:
	var panel = PanelContainer.new()

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.0, 0.02, 0.92)
	panel_style.set_border_width_all(4)
	panel_style.border_color = Color(0.9, 0.12, 0.12, 1.0)
	panel_style.set_corner_radius_all(13)
	panel.add_theme_stylebox_override("panel", panel_style)

	panel.custom_minimum_size = Vector2(120, 40)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	_hearts_container = HBoxContainer.new()
	_hearts_container.add_theme_constant_override("separation", 5)
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
	panel_style.set_border_width_all(4)
	panel_style.border_color = Color(0.9, 0.75, 0.1, 1.0)
	panel_style.set_corner_radius_all(13)
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_bottom", 3)
	panel.add_child(margin)

	var hbox = HBoxContainer.new()
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
		style.set_border_width_all(3)
		style.border_color = Color(0.75, 0.6, 0.05)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 3
		style.corner_radius_bottom_right = 3

		var bullet = Panel.new()
		bullet.custom_minimum_size = Vector2(16, 34)
		bullet.add_theme_stylebox_override("panel", style)

		_bullet_styles.append(style)
		_bullet_panels.append(bullet)
		_bullets_container.add_child(bullet)


func _eject_shell(index: int, move_dir: Vector2 = Vector2.ZERO):
	if index < 0 or index >= _bullet_panels.size():
		return
	var source: Panel = _bullet_panels[index]
	await get_tree().process_frame

	var start_pos = source.get_global_rect().position

	var shell = Panel.new()
	shell.size = Vector2(15, 35)
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

	var vel: Vector2
	if move_dir.length() > 10.0:
		var dir = move_dir.normalized()
		vel = dir * randf_range(700, 1000)
		vel.y -= randf_range(400, 700)
		vel.x += randf_range(-80, 80)
	else:
		vel = Vector2(randf_range(-500, 500), randf_range(-1100, -700))

	_bouncing_shells.append({
		"panel": shell,
		"vel": vel,
		"time_left": 5.0
	})


func try_collect_shell(screen_pos: Vector2) -> bool:
	for data in _bouncing_shells:
		var p: Panel = data.panel
		if not is_instance_valid(p):
			continue
		# Expand hit area so it's easier to click
		var rect = Rect2(p.position - Vector2(50, 50), p.size + Vector2(100, 100))
		if rect.has_point(screen_pos):
			var pickup_pos = p.position + p.size * 0.5
			p.queue_free()
			_bouncing_shells.erase(data)
			_show_ammo_pickup_text(pickup_pos)
			return true
	return false


func _show_ammo_pickup_text(pos: Vector2):
	var label = Label.new()
	label.text = "+1 Ammo"
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.25, 1.0, 0.35))
	label.position = pos - Vector2(35, 10)
	add_child(label)

	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 70.0, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	await tween.finished
	if is_instance_valid(label):
		label.queue_free()


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


func set_ammo(current: int, max_val: int, move_dir: Vector2 = Vector2.ZERO):
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
		_eject_shell(current, move_dir)

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
