extends CanvasLayer

const _DOS_FONT = preload("res://Perfect DOS VGA 437.ttf")

static var _heart_scr: GDScript = null
static var _bullet_scr: GDScript = null

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
var _level: int = 1
var _level_label: Label = null
var _score_at_last_level_up: int = 0
var _xp_bar: ProgressBar = null

var _dash_bar: ProgressBar = null
var _boss_timer_row: Control = null
var _boss_timer_bar: ProgressBar = null
var _boss_bar_container: Control = null
var _boss_timer_label: Label = null
var _boss_timer_skull: Label = null
var _boss_hp_label: Label = null
var _dash_fill_style: StyleBoxFlat = null
var _ammo_style: String = "gun"
var _ammo_border_style: StyleBoxFlat = null

var _ammo_panel_container: PanelContainer = null
var _energy_panel: PanelContainer = null
var _energy_bar: ProgressBar = null
var _energy_fill_style: StyleBoxFlat = null
var _energy_icon: Label = null
var _laser_starter = null
var _revolver_panel: Control = null
var _drum_left = null
var _drum_right = null

func _level_threshold(level: int) -> int:
	return int(100.0 * level * 1.3 + 400.0 / float(level))

func _ready():
	ThemeDB.fallback_font = _DOS_FONT
	add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build():
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 13)
	add_child(_vbox)
	_vbox.add_child(_build_dash_bar())
	_vbox.add_child(_build_hp_panel())

	# Boss timer anchored to top center, independent of bottom HUD
	var top_anchor := CenterContainer.new()
	top_anchor.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_anchor.offset_top = 100
	top_anchor.offset_bottom = 148
	top_anchor.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(top_anchor)
	_boss_timer_row = _build_boss_timer()
	top_anchor.add_child(_boss_timer_row)

	var bottom_row = HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 16)
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_child(bottom_row)
	_ammo_panel_container = _build_ammo_panel()
	bottom_row.add_child(_ammo_panel_container)
	_revolver_panel = _build_revolver_panel()
	_revolver_panel.visible = false
	bottom_row.add_child(_revolver_panel)
	_laser_starter = _build_starter_widget()
	_laser_starter.visible = false
	bottom_row.add_child(_laser_starter)
	_energy_panel = _build_energy_panel()
	_energy_panel.visible = false
	bottom_row.add_child(_energy_panel)

	# Score / level anchored to bottom-right corner
	var score_anchor := Control.new()
	score_anchor.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	score_anchor.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	score_anchor.grow_vertical = Control.GROW_DIRECTION_BEGIN
	score_anchor.offset_bottom = -80
	score_anchor.offset_right = -100
	score_anchor.offset_left = -340
	score_anchor.offset_top = -180
	add_child(score_anchor)

	var score_vbox := VBoxContainer.new()
	score_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	score_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	score_anchor.add_child(score_vbox)

	_level_label = Label.new()
	_level_label.text = "LVL 1"
	_level_label.add_theme_font_override("font", _DOS_FONT)
	_level_label.add_theme_font_size_override("font_size", 32)
	_level_label.add_theme_color_override("font_color", Color(0.15, 1.0, 0.3, 1.0))
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_vbox.add_child(_level_label)

	_score_label = Label.new()
	_score_label.text = "0"
	_score_label.add_theme_font_override("font", _DOS_FONT)
	_score_label.add_theme_font_size_override("font_size", 64)
	_score_label.add_theme_color_override("font_color", Color.WHITE)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_vbox.add_child(_score_label)

	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(0, 6)
	_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp_bar.max_value = 1.0
	_xp_bar.value = 0.0
	_xp_bar.step = 0.0001
	_xp_bar.show_percentage = false
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.2, 1.0, 0.45)
	xp_fill.set_corner_radius_all(3)
	_xp_bar.add_theme_stylebox_override("fill", xp_fill)
	var xp_bg := StyleBoxFlat.new()
	xp_bg.bg_color = Color(0.04, 0.1, 0.06, 0.85)
	xp_bg.set_corner_radius_all(3)
	_xp_bar.add_theme_stylebox_override("background", xp_bg)
	score_vbox.add_child(_xp_bar)


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
		var p: Control = data.panel

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


func _update_xp_bar() -> void:
	if not _xp_bar:
		return
	var threshold := _level_threshold(_level)
	var progress := float(_score - _score_at_last_level_up) / float(max(threshold, 1))
	_xp_bar.value = clampf(progress, 0.0, 1.0)


func add_score(amount: int) -> void:
	_score += amount
	if not _score_label:
		return
	_score_label.text = str(_score)
	_score_label.add_theme_color_override("font_color", _score_color())
	_update_xp_bar()
	var tween = create_tween()
	tween.tween_property(_score_label, "scale", Vector2(1.35, 1.35), 0.07)
	tween.parallel().tween_property(_score_label, "modulate", Color(2.5, 2.0, 0.4, 1.0), 0.07)
	tween.tween_property(_score_label, "scale", Vector2(1.0, 1.0), 0.13)
	tween.parallel().tween_property(_score_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.13)
	_check_level_up()


func _check_level_up() -> void:
	var next_threshold := _score_at_last_level_up + _level_threshold(_level)
	if _score < next_threshold:
		return
	_score_at_last_level_up = next_threshold
	_level += 1
	if _xp_bar:
		_xp_bar.value = 0.0
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


func show_damage_popup(amount: int, world_pos: Vector2) -> void:
	var screen_pos := get_viewport().get_canvas_transform() * world_pos
	var label := Label.new()
	label.text = str(amount)
	label.add_theme_font_override("font", _DOS_FONT)
	label.add_theme_font_size_override("font_size", 96 if amount >= 10 else 42)
	label.add_theme_color_override("font_color", Color(1.0, 0.12, 0.12))
	label.position = screen_pos + Vector2(randf_range(-12, 12), -20)
	add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 55.0, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	await tween.finished
	if is_instance_valid(label):
		label.queue_free()


func show_score_popup(amount: int, world_pos: Vector2) -> void:
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * world_pos
	var label = Label.new()
	label.text = "+%d" % amount
	label.add_theme_font_override("font", _DOS_FONT)
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", _score_color())
	label.position = screen_pos - Vector2(40, 30)
	label.pivot_offset = Vector2(40, 35)
	add_child(label)
	var bump = create_tween()
	bump.tween_property(label, "scale", Vector2(1.35, 1.35), 0.07)
	bump.parallel().tween_property(label, "modulate", Color(2.5, 2.0, 0.4, 1.0), 0.07)
	bump.parallel().tween_property(label, "rotation", deg_to_rad(45.0), 0.07)
	bump.tween_property(label, "scale", Vector2(1.0, 1.0), 0.13)
	bump.parallel().tween_property(label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.13)
	bump.parallel().tween_property(label, "rotation", 0.0, 0.13)
	await bump.finished
	if not is_instance_valid(label):
		return
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 110.0, 2.0)
	tween.tween_property(label, "modulate:a", 0.0, 2.0)
	await tween.finished
	if is_instance_valid(label):
		label.queue_free()


func _show_upgrade_panel(panel_title: String = "LEVEL UP! - CHOOSE AN UPGRADE", upgrade_pool: Variant = null) -> void:
	var sfx := AudioStreamPlayer.new()
	sfx.stream = load("res://Audio/Player/level_up_sound_1.mp3")
	sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
	var music = get_tree().get_first_node_in_group("music")
	if music:
		music.volume_db = linear_to_db(0.5)
	get_tree().paused = true

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

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
	title.text = panel_title
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

	var upgrades: Array = (upgrade_pool as Array) if upgrade_pool != null else _build_upgrade_pool()
	var card_infos: Array = []
	for upg in upgrades:
		card_infos.append(_add_upgrade_card(hbox, upg.sym, upg.title, upg.get("desc", ""), upg.color, overlay, upg.fn, upg.get("stats", []), upg.get("weapon", "gun")))

	# Spin for 2 seconds (timer runs even while tree is paused), then reveal
	await get_tree().create_timer(2.0, true).timeout

	for info in card_infos:
		var spin_t: Tween = info.spin_tween
		if is_instance_valid(spin_t):
			spin_t.kill()
		var q_lbl: Label = info.q_lbl
		var reveal: Callable = info.reveal
		var rt: Tween = q_lbl.create_tween()
		rt.tween_property(q_lbl, "modulate:a", 0.0, 0.15)
		rt.tween_callback(reveal)


func _add_upgrade_card(parent: HBoxContainer, symbol: String, title: String,
		desc: String, color: Color, overlay: ColorRect, apply_func: Callable,
		stat_changes: Array = [], weapon_type: String = "gun") -> Dictionary:
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.05, 0.05, 0.08, 0.95)
	card_style.set_border_width_all(5)
	card_style.border_color = color
	card_style.set_corner_radius_all(16)

	# Panel (not PanelContainer) so children can be freely positioned for the scroll
	var card := Panel.new()
	card.custom_minimum_size = Vector2(300, 700)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.add_theme_stylebox_override("panel", card_style)
	card.clip_contents = true
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(card)

	# "?" label scrolls top-to-bottom like a slot machine drum
	var q_lbl := Label.new()
	q_lbl.text = "?"
	q_lbl.add_theme_font_override("font", _DOS_FONT)
	q_lbl.add_theme_font_size_override("font_size", 220)
	q_lbl.add_theme_color_override("font_color", Color(color.r, color.g, color.b, 0.7))
	q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q_lbl.custom_minimum_size = Vector2(300, 700)
	q_lbl.position = Vector2(0, -700)
	card.add_child(q_lbl)

	var spin_t := card.create_tween().set_loops()
	spin_t.tween_property(q_lbl, "position:y", 700.0, 0.45).from(-700.0)

	# Reveal: fade out "?", add real content as anchored VBoxContainer
	var reveal := func():
		q_lbl.queue_free()

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 24)
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card.add_child(vbox)

		if weapon_type == "gun":
			var rifle_icon := TextureRect.new()
			rifle_icon.texture = load("res://player/riffle.png") as Texture2D
			rifle_icon.custom_minimum_size = Vector2(96, 96)
			rifle_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rifle_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			rifle_icon.modulate = Color(1.0, 0.92, 0.0, 1.0)
			vbox.add_child(rifle_icon)
		else:
			var icon_lbl := Label.new()
			icon_lbl.text = _get_weapon_ascii(weapon_type)
			icon_lbl.add_theme_font_override("font", _DOS_FONT)
			icon_lbl.add_theme_font_size_override("font_size", 12)
			icon_lbl.add_theme_color_override("font_color", color)
			icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			icon_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
			icon_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			vbox.add_child(icon_lbl)

		var sym := Label.new()
		sym.text = symbol
		sym.add_theme_font_override("font", _DOS_FONT)
		sym.add_theme_font_size_override("font_size", 90)
		sym.add_theme_color_override("font_color", color)
		sym.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(sym)

		var title_lbl := Label.new()
		title_lbl.text = title
		title_lbl.add_theme_font_override("font", _DOS_FONT)
		title_lbl.add_theme_font_size_override("font_size", 38)
		title_lbl.add_theme_color_override("font_color", Color.WHITE)
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(title_lbl)

		if stat_changes.is_empty():
			var desc_lbl := Label.new()
			desc_lbl.text = desc
			desc_lbl.add_theme_font_size_override("font_size", 26)
			desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
			desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(desc_lbl)
		else:
			var stats_vbox := VBoxContainer.new()
			stats_vbox.add_theme_constant_override("separation", 8)
			vbox.add_child(stats_vbox)
			for s in stat_changes:
				var row := HBoxContainer.new()
				row.alignment = BoxContainer.ALIGNMENT_CENTER
				row.add_theme_constant_override("separation", 10)
				stats_vbox.add_child(row)
				var name_lbl := Label.new()
				name_lbl.text = s.label + ":"
				name_lbl.add_theme_font_override("font", _DOS_FONT)
				name_lbl.add_theme_font_size_override("font_size", 18)
				name_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
				name_lbl.custom_minimum_size = Vector2(90, 0)
				name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				row.add_child(name_lbl)
				var val_lbl := Label.new()
				var is_buff: bool = s.buff
				var arrow := " ↑" if is_buff else " ↓"
				var val_color := Color(0.2, 1.0, 0.45) if is_buff else Color(1.0, 0.3, 0.3)
				val_lbl.text = "%s → %s%s" % [_fmt_stat(s.old), _fmt_stat(s.new), arrow]
				val_lbl.add_theme_font_override("font", _DOS_FONT)
				val_lbl.add_theme_font_size_override("font_size", 18)
				val_lbl.add_theme_color_override("font_color", val_color)
				row.add_child(val_lbl)

		var hint := Label.new()
		hint.text = "CLICK TO CHOOSE"
		hint.add_theme_font_override("font", _DOS_FONT)
		hint.add_theme_font_size_override("font_size", 15)
		hint.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(hint)

		card.mouse_filter = Control.MOUSE_FILTER_STOP

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
			var p := AudioStreamPlayer.new()
			p.stream = load("res://Audio/UI/uI_success_sound_1.mp3")
			p.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(p)
			p.play()
			p.finished.connect(p.queue_free)
			var mus = get_tree().get_first_node_in_group("music")
			if mus:
				mus.volume_db = mus.get_meta("base_volume_db", 0.0)
			apply_func.call()
			overlay.queue_free()
			get_tree().paused = false
	)

	return {"card": card, "reveal": reveal, "spin_tween": spin_t, "q_lbl": q_lbl}


func _roll_upgrade_level() -> int:
	var r := randf()
	if r < 0.25: return 3
	if r < 0.60: return 2
	return 1

func _fmt_stat(val: Variant) -> String:
	if val is int:
		return str(val)
	if val is float:
		if absf(val - roundf(val)) < 0.05:
			return str(int(roundf(val)))
		return "%.1f" % val
	return str(val)

func _sc(label: String, old: Variant, new_val: Variant, buff: bool) -> Dictionary:
	return {"label": label, "old": old, "new": new_val, "buff": buff}

func _build_upgrade_pool(force_level: int = 0) -> Array:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return []
	var LC := {1: Color(0.3, 0.6, 1.0), 2: Color(0.75, 0.25, 1.0), 3: Color(1.0, 0.55, 0.1)}
	var a: int     = player.max_ammo
	var gd: float  = player.gun_damage
	var sc: float  = player.shoot_cooldown
	var sp: int    = player.sg_particle_count
	var sd: float  = player.sg_particle_damage
	var sl: float  = player.sg_particle_lifetime
	var sr: float  = float(player.reload_duration) + float(player.sg_reload_bonus)
	var le: float  = player.laser_max_energy
	var ld: float  = float(player.laser_damage_per_tick) * 5.0
	var lw: float  = player.laser_beam_width
	var hp: int    = player.max_health
	var ch: int    = player.current_health
	var cats := [
		# Gun: Ammo
		[{"sym":"⬡","weapon":"gun","title":"GUN AMMO I","fn":func(): player.gun_upgrade_ammo(1),
		  "stats":[_sc("AMMO",a,a+1,true),_sc("DAMAGE",gd,maxf(1.0,gd-1),false)]},
		 {"sym":"⬡","weapon":"gun","title":"GUN AMMO II","fn":func(): player.gun_upgrade_ammo(2),
		  "stats":[_sc("AMMO",a,a+2,true),_sc("DAMAGE",gd,maxf(1.0,gd-1),false)]},
		 {"sym":"⬡","weapon":"gun","title":"GUN AMMO III","fn":func(): player.gun_upgrade_ammo(3),
		  "stats":[_sc("AMMO",a,a+4,true)]}],
		# Gun: Damage
		[{"sym":"▲","weapon":"gun","title":"GUN DMG I","fn":func(): player.gun_upgrade_damage(1),
		  "stats":[_sc("DAMAGE",gd,gd+2,true),_sc("COOLDOWN",sc,snappedf(sc*1.05,0.01),false)]},
		 {"sym":"▲","weapon":"gun","title":"GUN DMG II","fn":func(): player.gun_upgrade_damage(2),
		  "stats":[_sc("DAMAGE",gd,gd+4,true),_sc("COOLDOWN",sc,snappedf(sc*1.10,0.01),false)]},
		 {"sym":"▲","weapon":"gun","title":"GUN DMG III","fn":func(): player.gun_upgrade_damage(3),
		  "stats":[_sc("DAMAGE",gd,gd+8,true)]}],
		# Gun: Fire Rate
		[{"sym":"⚡","weapon":"gun","title":"GUN RATE I","fn":func(): player.gun_upgrade_fire_rate(1),
		  "stats":[_sc("COOLDOWN",sc,snappedf(sc*0.95,0.01),true),_sc("DAMAGE",gd,maxf(1.0,gd-2),false)]},
		 {"sym":"⚡","weapon":"gun","title":"GUN RATE II","fn":func(): player.gun_upgrade_fire_rate(2),
		  "stats":[_sc("COOLDOWN",sc,snappedf(sc*0.90,0.01),true),_sc("DAMAGE",gd,maxf(1.0,gd-2),false)]},
		 {"sym":"⚡","weapon":"gun","title":"GUN RATE III","fn":func(): player.gun_upgrade_fire_rate(3),
		  "stats":[_sc("COOLDOWN",sc,snappedf(sc*0.85,0.01),true)]}],
		# Shotgun: Particles
		[{"sym":"✦","weapon":"shotgun","title":"SG SHOTS I","fn":func(): player.shotgun_upgrade_particles(1),
		  "stats":[_sc("SHOTS",sp,sp+1,true),_sc("DAMAGE",sd,maxf(2.0,sd-1),false)]},
		 {"sym":"✦","weapon":"shotgun","title":"SG SHOTS II","fn":func(): player.shotgun_upgrade_particles(2),
		  "stats":[_sc("SHOTS",sp,sp+2,true),_sc("DAMAGE",sd,maxf(2.0,sd-2),false)]},
		 {"sym":"✦","weapon":"shotgun","title":"SG SHOTS III","fn":func(): player.shotgun_upgrade_particles(3),
		  "stats":[_sc("SHOTS",sp,sp+4,true),_sc("DAMAGE",sd,maxf(2.0,sd-1),false)]}],
		# Shotgun: Damage
		[{"sym":"✦","weapon":"shotgun","title":"SG DMG I","fn":func(): player.shotgun_upgrade_damage(1),
		  "stats":[_sc("DAMAGE",sd,maxf(2.0,sd+3),true),_sc("RELOAD",sr,sr+2.0,false)]},
		 {"sym":"✦","weapon":"shotgun","title":"SG DMG II","fn":func(): player.shotgun_upgrade_damage(2),
		  "stats":[_sc("DAMAGE",sd,maxf(2.0,sd+6),true),_sc("RELOAD",sr,sr+4.0,false)]},
		 {"sym":"✦","weapon":"shotgun","title":"SG DMG III","fn":func(): player.shotgun_upgrade_damage(3),
		  "stats":[_sc("DAMAGE",sd,maxf(2.0,sd+9),true),_sc("RELOAD",sr,sr+2.0,false)]}],
		# Shotgun: Lifetime
		[{"sym":"✦","weapon":"shotgun","title":"SG LIFE I","fn":func(): player.shotgun_upgrade_lifetime(1),
		  "stats":[_sc("LIFE",sl,sl+1.0,true),_sc("DAMAGE",sd,maxf(2.0,sd-1),false)]},
		 {"sym":"✦","weapon":"shotgun","title":"SG LIFE II","fn":func(): player.shotgun_upgrade_lifetime(2),
		  "stats":[_sc("LIFE",sl,sl+1.5,true)]},
		 {"sym":"✦","weapon":"shotgun","title":"SG LIFE III","fn":func(): player.shotgun_upgrade_lifetime(3),
		  "stats":[_sc("LIFE",sl,4.0,true),_sc("DAMAGE",sd,maxf(2.0,sd-3),false)]}],
		# Laser: Battery
		[{"sym":"⚡","weapon":"laser","title":"LASER BAT I","fn":func(): player.laser_upgrade_battery(1),
		  "stats":[_sc("BATTERY",le,maxf(1.0,le+0.5),true),_sc("DPS",ld,maxf(1.0,ld-3),false)]},
		 {"sym":"⚡","weapon":"laser","title":"LASER BAT II","fn":func(): player.laser_upgrade_battery(2),
		  "stats":[_sc("BATTERY",le,maxf(1.0,le+1.0),true),_sc("DPS",ld,maxf(1.0,ld-2),false)]},
		 {"sym":"⚡","weapon":"laser","title":"LASER BAT III","fn":func(): player.laser_upgrade_battery(3),
		  "stats":[_sc("BATTERY",le,maxf(1.0,le+3.0),true),_sc("DPS",ld,maxf(1.0,ld-3),false)]}],
		# Laser: Damage
		[{"sym":"⚡","weapon":"laser","title":"LASER DMG I","fn":func(): player.laser_upgrade_damage(1),
		  "stats":[_sc("DPS",ld,ld+2,true),_sc("BEAM",lw,maxf(2.0,lw-3),false)]},
		 {"sym":"⚡","weapon":"laser","title":"LASER DMG II","fn":func(): player.laser_upgrade_damage(2),
		  "stats":[_sc("DPS",ld,ld+5,true),_sc("BEAM",lw,maxf(2.0,lw-5),false)]},
		 {"sym":"⚡","weapon":"laser","title":"LASER DMG III","fn":func(): player.laser_upgrade_damage(3),
		  "stats":[_sc("DPS",ld,ld+10,true),_sc("BEAM",lw,maxf(2.0,lw-8),false)]}],
		# Laser: Width
		[{"sym":"⚡","weapon":"laser","title":"LASER WIDTH I","fn":func(): player.laser_upgrade_width(1),
		  "stats":[_sc("BEAM",lw,maxf(2.0,lw+2),true),_sc("BATTERY",le,maxf(1.0,le-0.5),false)]},
		 {"sym":"⚡","weapon":"laser","title":"LASER WIDTH II","fn":func(): player.laser_upgrade_width(2),
		  "stats":[_sc("BEAM",lw,maxf(2.0,lw+4),true),_sc("BATTERY",le,maxf(1.0,le-1.0),false)]},
		 {"sym":"⚡","weapon":"laser","title":"LASER WIDTH III","fn":func(): player.laser_upgrade_width(3),
		  "stats":[_sc("BEAM",lw,maxf(2.0,lw+8),true)]}],
		# Player: HP
		[{"sym":"♥","weapon":"shield","title":"HP UP","fn":func(): player.upgrade_hp(),
		  "stats":[_sc("MAX HP",hp,hp+2,true)]},
		 {"sym":"♥","weapon":"shield","title":"HP UP","fn":func(): player.upgrade_hp(),
		  "stats":[_sc("MAX HP",hp,hp+2,true)]},
		 {"sym":"♥","weapon":"shield","title":"HP UP","fn":func(): player.upgrade_hp(),
		  "stats":[_sc("MAX HP",hp,hp+2,true)]}],
		# Player: Heal
		[{"sym":"✦","weapon":"shield","title":"FULL HEAL","fn":func(): player.upgrade_heal(),
		  "stats":[_sc("HP",ch,hp,ch<hp)]},
		 {"sym":"✦","weapon":"shield","title":"FULL HEAL","fn":func(): player.upgrade_heal(),
		  "stats":[_sc("HP",ch,hp,ch<hp)]},
		 {"sym":"✦","weapon":"shield","title":"FULL HEAL","fn":func(): player.upgrade_heal(),
		  "stats":[_sc("HP",ch,hp,ch<hp)]}],
	]
	cats.shuffle()
	var result := []
	for cat in cats.slice(0, 3):
		var lvl := force_level if force_level > 0 else _roll_upgrade_level()
		var d: Dictionary = cat[lvl - 1].duplicate()
		d["level"] = lvl
		d["color"] = LC[lvl]
		result.append(d)
	return result


func show_wave_title() -> void:
	var label := Label.new()
	label.text = "NEW WAVE INCOMING"
	label.add_theme_font_override("font", _DOS_FONT)
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 30
	label.offset_bottom = 100
	add_child(label)

	var glow := create_tween().set_loops()
	glow.tween_property(label, "modulate", Color(2.2, 1.8, 0.4, 1.0), 0.12)
	glow.tween_property(label, "modulate", Color(1.0, 0.85, 0.2, 1.0), 0.18)

	await get_tree().create_timer(3.0).timeout
	glow.kill()
	var fade := create_tween()
	fade.tween_property(label, "modulate:a", 0.0, 0.4)
	await fade.finished
	if is_instance_valid(label):
		label.queue_free()


func show_boss_reward() -> void:
	if _boss_timer_row:
		_boss_timer_row.hide()
	_show_upgrade_panel(
		"Big boy defeated, choose your reward",
		_build_upgrade_pool(3)
	)


func _build_boss_timer() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	# Skull icon
	_boss_timer_skull = Label.new()
	_boss_timer_skull.text = "☠"
	_boss_timer_skull.add_theme_font_size_override("font_size", 22)
	_boss_timer_skull.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1))
	_boss_timer_skull.modulate = Color(1.0, 0.1, 0.1)
	_boss_timer_skull.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_boss_timer_skull)

	# Container — holds bar and HP label overlaid
	_boss_bar_container = Control.new()
	_boss_bar_container.custom_minimum_size = Vector2(1200, 6)
	_boss_bar_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_boss_bar_container)

	_boss_timer_bar = ProgressBar.new()
	_boss_timer_bar.anchor_right = 1.0
	_boss_timer_bar.anchor_bottom = 1.0
	_boss_timer_bar.max_value = 1.0
	_boss_timer_bar.value = 1.0
	_boss_timer_bar.step = 0.0001
	_boss_timer_bar.show_percentage = false

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.1, 0.1)
	fill.set_corner_radius_all(4)
	_boss_timer_bar.add_theme_stylebox_override("fill", fill)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.0, 0.0, 0.9)
	bg.set_corner_radius_all(4)
	_boss_timer_bar.add_theme_stylebox_override("background", bg)
	_boss_bar_container.add_child(_boss_timer_bar)

	# HP text overlaid on bar (hidden until boss spawns)
	_boss_hp_label = Label.new()
	_boss_hp_label.anchor_right = 1.0
	_boss_hp_label.anchor_bottom = 1.0
	_boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_hp_label.add_theme_font_size_override("font_size", 20)
	_boss_hp_label.add_theme_color_override("font_color", Color.WHITE)
	_boss_hp_label.visible = false
	_boss_bar_container.add_child(_boss_hp_label)

	# Countdown text to the right of the bar
	_boss_timer_label = Label.new()
	_boss_timer_label.text = "01:00"
	_boss_timer_label.add_theme_font_size_override("font_size", 22)
	_boss_timer_label.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1))
	_boss_timer_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_boss_timer_label)

	return row


func update_boss_timer(fraction: float, time_left: float = 0.0) -> void:
	if _boss_timer_bar:
		_boss_timer_bar.value = clampf(fraction, 0.0, 1.0)
	if _boss_timer_label:
		var mins := int(time_left) / 60
		var secs := int(time_left) % 60
		_boss_timer_label.text = "%02d:%02d" % [mins, secs]


func hide_boss_timer() -> void:
	# Hide countdown-only elements
	if _boss_timer_label:
		_boss_timer_label.hide()
	if _boss_timer_skull:
		_boss_timer_skull.hide()
	# Animate bar from 6px to 50px tall, then reveal HP label
	if _boss_bar_container:
		_boss_timer_bar.value = 1.0
		var tween := create_tween()
		tween.tween_property(_boss_bar_container, "custom_minimum_size:y", 50.0, 0.5)
		tween.tween_callback(func():
			if _boss_hp_label:
				_boss_hp_label.visible = true
		)


func update_boss_hp(fraction: float, current_hp: int) -> void:
	if _boss_timer_bar:
		_boss_timer_bar.value = clampf(fraction, 0.0, 1.0)
	if _boss_hp_label and _boss_hp_label.visible:
		_boss_hp_label.text = str(current_hp)


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
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

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

	if not _heart_scr:
		_heart_scr = GDScript.new()
		_heart_scr.source_code = """
extends Control
var filled: bool = true
var active_color: Color = Color(1.0, 0.15, 0.15)
var inactive_color: Color = Color(0.25, 0.05, 0.05, 0.4)
const PAT = [54, 127, 127, 62, 28, 8]
const COLS = 7
const BLOCK = 4
func _draw() -> void:
\tvar col = active_color if filled else inactive_color
\tfor row in 6:
\t\tfor c in COLS:
\t\t\tif PAT[row] & (1 << (COLS - 1 - c)):
\t\t\t\tdraw_rect(Rect2(c * BLOCK, row * BLOCK, BLOCK, BLOCK), col)
"""
		_heart_scr.reload()

	for i in count:
		var heart := Control.new()
		heart.set_script(_heart_scr)
		heart.custom_minimum_size = Vector2(28, 24)
		_heart_labels.append(heart)
		_hearts_container.add_child(heart)


func set_weapon_mode(mode: String) -> void:
	var laser_mode    := mode == "laser"
	var revolver_mode := mode == "revolver"
	if _ammo_panel_container:
		_ammo_panel_container.visible = not laser_mode and not revolver_mode
	if _energy_panel:
		_energy_panel.visible = laser_mode
	if _laser_starter:
		_laser_starter.visible = laser_mode
	if _revolver_panel:
		_revolver_panel.visible = revolver_mode
	if not laser_mode and not revolver_mode:
		_update_ammo_style("shotgun" if mode == "shotgun" else "gun")


func set_energy(fraction: float, is_reloading: bool = false) -> void:
	if not _energy_bar or not _energy_fill_style:
		return
	_energy_bar.value = clampf(fraction, 0.0, 1.0)
	_energy_fill_style.bg_color = Color(0.9, 0.55, 0.1) if is_reloading \
		else Color(0.2, 1.0, 0.4)


func _build_energy_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(120, 40)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.06, 0.02, 0.92)
	style.set_border_width_all(4)
	style.border_color = Color(0.1, 0.9, 0.4, 1.0)
	style.set_corner_radius_all(13)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	margin.add_child(hbox)

	_energy_icon = Label.new()
	_energy_icon.text = "⚡"
	_energy_icon.add_theme_font_size_override("font_size", 20)
	_energy_icon.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	_energy_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(_energy_icon)

	_energy_bar = ProgressBar.new()
	_energy_bar.custom_minimum_size = Vector2(72, 20)
	_energy_bar.max_value = 1.0
	_energy_bar.value = 1.0
	_energy_bar.show_percentage = false
	_energy_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_energy_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_energy_fill_style = StyleBoxFlat.new()
	_energy_fill_style.bg_color = Color(0.2, 1.0, 0.4)
	_energy_fill_style.set_corner_radius_all(3)
	_energy_bar.add_theme_stylebox_override("fill", _energy_fill_style)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.08, 0.04, 0.9)
	bg.set_corner_radius_all(3)
	_energy_bar.add_theme_stylebox_override("background", bg)

	hbox.add_child(_energy_bar)

	return panel


func _build_starter_widget() -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(22, 48)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var scr := GDScript.new()
	scr.source_code = """
extends Control
var spin_offset: float = 0.0
func spin(angle: float) -> void:
\tvar spacing: float = 8.0
\tspin_offset = fmod(spin_offset + angle / TAU * spacing, spacing)
\tqueue_redraw()
func _draw() -> void:
\tvar col: Color = Color(0.25, 1.0, 0.45, 0.9)
\tvar fill: Color = Color(0.05, 0.2, 0.08, 0.5)
\tvar w: float = size.x
\tvar h: float = size.y
\tvar r: float = w * 0.5 - 1.0
\tvar top_y: float = r
\tvar bot_y: float = h - r
\tdraw_rect(Rect2(1.0, top_y, w - 2.0, bot_y - top_y), fill)
\tdraw_circle(Vector2(w * 0.5, top_y), r - 0.5, fill)
\tdraw_circle(Vector2(w * 0.5, bot_y), r - 0.5, fill)
\tvar spacing: float = 8.0
\tvar y: float = top_y + spin_offset
\twhile y <= bot_y:
\t\tif y >= top_y:
\t\t\tdraw_line(Vector2(2.0, y), Vector2(w - 2.0, y), Color(col.r, col.g, col.b, 0.6), 1.5)
\t\ty += spacing
\tdraw_line(Vector2(1.0, top_y), Vector2(1.0, bot_y), col, 2.0)
\tdraw_line(Vector2(w - 1.0, top_y), Vector2(w - 1.0, bot_y), col, 2.0)
\tdraw_arc(Vector2(w * 0.5, top_y), r, PI, TAU, 20, col, 2.0)
\tdraw_arc(Vector2(w * 0.5, bot_y), r, 0.0, PI, 20, col, 2.0)
"""
	scr.reload()
	s.set_script(scr)
	return s


func spin_starter(angle: float) -> void:
	if _laser_starter and is_instance_valid(_laser_starter) \
			and _laser_starter.has_method("spin"):
		_laser_starter.spin(angle)


func _update_ammo_style(style: String) -> void:
	if _ammo_style == style:
		return
	_ammo_style = style
	var is_sg := style == "shotgun"
	if _ammo_border_style:
		_ammo_border_style.bg_color = Color(0.06, 0.02, 0.0, 0.92) if is_sg \
			else Color(0.04, 0.03, 0.0, 0.92)
		_ammo_border_style.border_color = Color(0.9, 0.40, 0.1, 1.0) if is_sg \
			else Color(0.9, 0.75, 0.1, 1.0)
	if _current_max_ammo > 0:
		_build_bullet_icons(_current_max_ammo)
	_last_ammo = -1


func spin_revolver_visual(glowing: bool) -> void:
	if _drum_left and _drum_left.has_method("spin_visual"):
		_drum_left.spin_visual(glowing)
	if _drum_right and _drum_right.has_method("spin_visual"):
		_drum_right.spin_visual(glowing)


func shoot_revolver_drum() -> void:
	if _drum_left and _drum_left.has_method("shoot"):
		_drum_left.shoot()
	if _drum_right and _drum_right.has_method("shoot"):
		_drum_right.shoot()


func reset_revolver_drums() -> void:
	if _drum_left and _drum_left.has_method("reset"):
		_drum_left.reset()
	if _drum_right and _drum_right.has_method("reset"):
		_drum_right.reset()


func eject_shells_at(screen_pos: Vector2, count: int, move_dir: Vector2 = Vector2.ZERO) -> void:
	if not _bullet_scr:
		return
	var is_sg := _ammo_style == "shotgun"
	var cols := 5 if is_sg else 4
	var sz := Vector2(cols * 4, 6 * 4)
	for _i in count:
		var shell := Control.new()
		shell.set_script(_bullet_scr)
		shell.set("is_sg", is_sg)
		shell.set("is_shell", true)
		shell.set("state", 1)
		shell.size = sz
		shell.position = screen_pos + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
		add_child(shell)
		var vel: Vector2
		if move_dir.length() > 10.0:
			var d := move_dir.normalized()
			vel = d * randf_range(700, 1000)
			vel.y -= randf_range(400, 700)
			vel.x += randf_range(-80, 80)
		else:
			vel = Vector2(randf_range(-500, 500), randf_range(-1100, -700))
		_bouncing_shells.append({"panel": shell, "vel": vel, "time_left": 2.0})


func _build_revolver_panel() -> Control:
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 10)
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_drum_left  = _build_drum_widget()
	_drum_right = _build_drum_widget()
	container.add_child(_drum_left)
	container.add_child(_drum_right)
	return container


func _build_drum_widget() -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(52, 52)
	var scr := GDScript.new()
	scr.source_code = """
extends Control
var spent = [false, false, false, false, false, false]
var top_slot: int = 0
var rot: float = 0.0
var _tgt: float = 0.0
var glowing: bool = false
func shoot() -> void:
\tif spent[top_slot]: return
\tspent[top_slot] = true
\t_tgt += TAU / 6.0
\ttop_slot = (top_slot + 5) % 6
\tglowing = false
func spin_visual(glow: bool) -> void:
\tglowing = glow
\t_tgt += TAU / 6.0
func reset() -> void:
\tfor i in 6: spent[i] = false
\ttop_slot = 0; rot = 0.0; _tgt = 0.0; glowing = false; queue_redraw()
func _process(delta: float) -> void:
\tif abs(_tgt - rot) > 0.001:
\t\trot = lerp(rot, _tgt, delta * 14.0); queue_redraw()
func _draw() -> void:
\tvar c := Vector2(size.x * 0.5, size.y * 0.5)
\tvar r: float = min(c.x, c.y) - 2.0
\tvar sr: float = r * 0.60
\tvar br: float = r * 0.17
\tif glowing:
\t\tdraw_arc(c, r + 5.0, 0.0, TAU, 32, Color(1.0, 0.80, 0.15, 0.75), 4.0)
\t\tdraw_arc(c, r + 9.0, 0.0, TAU, 32, Color(1.0, 0.65, 0.05, 0.30), 3.0)
\tdraw_circle(c, r, Color(0.10, 0.06, 0.03, 0.95))
\tdraw_arc(c, r, 0.0, TAU, 32, Color(0.60, 0.40, 0.12, 0.9), 2.5)
\tfor i in 6:
\t\tvar a: float = rot + float(i) * TAU / 6.0 - PI * 0.5
\t\tvar p := c + Vector2(cos(a), sin(a)) * sr
\t\tif spent[i]:
\t\t\tdraw_circle(p, br, Color(0.06, 0.03, 0.01, 0.8))
\t\t\tdraw_arc(p, br, 0.0, TAU, 10, Color(0.4, 0.25, 0.05, 0.5), 1.0)
\t\telse:
\t\t\tdraw_circle(p, br, Color(0.90, 0.70, 0.12, 0.95))
\t\t\tdraw_arc(p, br, 0.0, TAU, 10, Color(1.0, 0.85, 0.2, 0.6), 1.0)
\tdraw_circle(c, 3.5, Color(0.55, 0.35, 0.08, 0.9))
\tdraw_line(Vector2(c.x, c.y - r - 5.0), Vector2(c.x, c.y - sr + br + 1.0), Color(0.9, 0.5, 0.1, 0.8), 2.0)
"""
	scr.reload()
	s.set_script(scr)
	return s


func _build_ammo_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(120, 40)

	_ammo_border_style = StyleBoxFlat.new()
	_ammo_border_style.bg_color = Color(0.04, 0.03, 0.0, 0.92)
	_ammo_border_style.set_border_width_all(4)
	_ammo_border_style.border_color = Color(0.9, 0.75, 0.1, 1.0)
	_ammo_border_style.set_corner_radius_all(13)
	panel.add_theme_stylebox_override("panel", _ammo_border_style)

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

	if not _bullet_scr:
		_bullet_scr = GDScript.new()
		_bullet_scr.source_code = """
extends Control
var state: int = 1
var is_sg: bool = false
var is_shell: bool = false
const BLOCK = 4
# 7.62 rifle: narrow ogive, copper FMJ tip, brass case, extractor groove, rim
const GUN_TIP_PAT  = [6, 6, 6, 15]
const GUN_BODY_PAT = [15, 15, 15, 6, 15]
const GUN_COLS = 4
# 28 GA shotgun shell: star-crimped hull top, yellow plastic hull, brass head
const SG_CRIMP_PAT = [14, 31]
const SG_HULL_PAT  = [31, 31, 31]
const SG_BRASS_PAT = [31, 31]
const SG_COLS = 5
func _draw() -> void:
\tif is_sg: _draw_sg()
\telse: _draw_gun()
func _draw_gun() -> void:
\tvar tip_col: Color
\tvar body_col: Color
\tvar groove_col: Color
\tmatch state:
\t\t1:
\t\t\ttip_col    = Color(0.72, 0.45, 0.18)
\t\t\tbody_col   = Color(0.90, 0.78, 0.22)
\t\t\tgroove_col = Color(0.55, 0.44, 0.10)
\t\t2:
\t\t\ttip_col    = Color(0.9, 0.55, 0.1)
\t\t\tbody_col   = Color(0.9, 0.55, 0.1)
\t\t\tgroove_col = Color(0.65, 0.38, 0.06)
\t\t_:
\t\t\ttip_col    = Color(0.10, 0.08, 0.02, 0.35)
\t\t\tbody_col   = Color(0.10, 0.08, 0.02, 0.35)
\t\t\tgroove_col = Color(0.10, 0.08, 0.02, 0.35)
\tvar tip_start: int = 3 if is_shell else 0
\tvar y: int = 0
\tfor row in range(tip_start, GUN_TIP_PAT.size()):
\t\tfor c in GUN_COLS:
\t\t\tif GUN_TIP_PAT[row] & (1 << (GUN_COLS - 1 - c)):
\t\t\t\tdraw_rect(Rect2(c * BLOCK, y * BLOCK, BLOCK, BLOCK), tip_col)
\t\ty += 1
\tvar groove_row: int = GUN_BODY_PAT.size() - 2
\tfor row in GUN_BODY_PAT.size():
\t\tfor c in GUN_COLS:
\t\t\tif GUN_BODY_PAT[row] & (1 << (GUN_COLS - 1 - c)):
\t\t\t\tvar col = groove_col if row == groove_row else body_col
\t\t\t\tdraw_rect(Rect2(c * BLOCK, y * BLOCK, BLOCK, BLOCK), col)
\t\ty += 1
func _draw_sg() -> void:
\tvar crimp_col: Color
\tvar hull_col: Color
\tvar brass_col: Color
\tmatch state:
\t\t1:
\t\t\tcrimp_col = Color(0.52, 0.40, 0.06)
\t\t\thull_col  = Color(0.95, 0.82, 0.08)
\t\t\tbrass_col = Color(0.88, 0.70, 0.18)
\t\t2:
\t\t\tcrimp_col = Color(0.70, 0.45, 0.08)
\t\t\thull_col  = Color(0.90, 0.55, 0.10)
\t\t\tbrass_col = Color(0.70, 0.50, 0.12)
\t\t_:
\t\t\tcrimp_col = Color(0.10, 0.08, 0.02, 0.35)
\t\t\thull_col  = Color(0.10, 0.08, 0.02, 0.35)
\t\t\tbrass_col = Color(0.10, 0.08, 0.02, 0.35)
\tvar crimp_start: int = 1 if is_shell else 0
\tvar y: int = 0
\tfor row in range(crimp_start, SG_CRIMP_PAT.size()):
\t\tfor c in SG_COLS:
\t\t\tif SG_CRIMP_PAT[row] & (1 << (SG_COLS - 1 - c)):
\t\t\t\tdraw_rect(Rect2(c * BLOCK, y * BLOCK, BLOCK, BLOCK), crimp_col)
\t\ty += 1
\tfor row in SG_HULL_PAT.size():
\t\tfor c in SG_COLS:
\t\t\tif SG_HULL_PAT[row] & (1 << (SG_COLS - 1 - c)):
\t\t\t\tdraw_rect(Rect2(c * BLOCK, y * BLOCK, BLOCK, BLOCK), hull_col)
\t\ty += 1
\tfor row in SG_BRASS_PAT.size():
\t\tfor c in SG_COLS:
\t\t\tif SG_BRASS_PAT[row] & (1 << (SG_COLS - 1 - c)):
\t\t\t\tdraw_rect(Rect2(c * BLOCK, y * BLOCK, BLOCK, BLOCK), brass_col)
\t\ty += 1
"""
		_bullet_scr.reload()

	var is_sg := _ammo_style == "shotgun"
	for i in count:
		var ctrl := Control.new()
		ctrl.set_script(_bullet_scr)
		ctrl.set("is_sg", is_sg)
		var cols := 5 if is_sg else 4
		var rows := 7 if is_sg else 9
		ctrl.custom_minimum_size = Vector2(cols * 4, rows * 4)
		ctrl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_bullet_styles.append(ctrl)
		_bullet_panels.append(ctrl)
		_bullets_container.add_child(ctrl)


func _eject_shell(index: int, move_dir: Vector2 = Vector2.ZERO):
	if index < 0 or index >= _bullet_panels.size():
		return
	var source: Control = _bullet_panels[index]
	await get_tree().process_frame

	var start_pos = source.get_global_rect().position

	var is_sg := _ammo_style == "shotgun"
	var cols := 5 if is_sg else 4
	var shell := Control.new()
	shell.set_script(_bullet_scr)
	shell.set("is_sg", is_sg)
	shell.set("is_shell", true)
	shell.set("state", 1)
	shell.size = Vector2(cols * 4, 6 * 4)
	shell.position = start_pos
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
		"time_left": 2.0
	})


func try_collect_shell(screen_pos: Vector2) -> bool:
	for data in _bouncing_shells:
		var p: Control = data.panel
		if not is_instance_valid(p):
			continue
		# Expand hit area so it's easier to click
		var rect = Rect2(p.position - Vector2(50, 50), p.size + Vector2(100, 100))
		if rect.has_point(screen_pos):
			var pickup_pos = p.position + p.size * 0.5
			p.queue_free()
			_bouncing_shells.erase(data)
			var sfx := AudioStreamPlayer.new()
			sfx.stream = load("res://Audio/UI/uI_success_sound_1.mp3")
			add_child(sfx)
			sfx.play()
			sfx.finished.connect(sfx.queue_free)
			_show_ammo_pickup_text(pickup_pos)
			return true
	return false


func _show_ammo_pickup_text(pos: Vector2):
	var label = Label.new()
	label.text = "+1 AMMO"
	label.add_theme_font_size_override("font_size", 64)
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
		_heart_labels[i].set("filled", i < current)
		_heart_labels[i].queue_redraw()

	if current <= 1:
		_start_pulse()
	else:
		_stop_pulse()


func set_ammo(current: int, max_val: int, move_dir: Vector2 = Vector2.ZERO):
	if max_val != _current_max_ammo:
		_build_bullet_icons(max_val)

	var shot_fired := _last_ammo > 0 and current < _last_ammo

	for i in _current_max_ammo:
		_bullet_styles[i].set("state", 1 if i < current else 0)
		_bullet_styles[i].queue_redraw()

	if shot_fired:
		_eject_shell(current, move_dir)

	_last_ammo = current


func set_reload_progress(progress: float):
	var lit_count = int(progress * _current_max_ammo)
	for i in _current_max_ammo:
		_bullet_styles[i].set("state", 2 if i < lit_count else 0)
		_bullet_styles[i].queue_redraw()


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
			_heart_labels[i].set("active_color", color)
			_heart_labels[i].queue_redraw()


func _get_weapon_ascii(weapon_type: String) -> String:
	match weapon_type:
		"gun":
			return (
				"      _     _______________________\n"
				+ " [###| |___/   ___   ___   _________)─╤─\n"
				+ "     |  ___   [___] [___] /\n"
				+ "     |_/   \\_]           /_]"
			)
		"shotgun":
			return (
				"         ______________________________________\n"
				+ "        / __________   _______________________ \\\n"
				+ " ______/_/          | |   [___][___][___]     \\_|\n"
				+ "|_______ _________  |_|\n"
				+ "        \\_]       \\_]"
			)
		"laser":
			return (
				"      ____________________________________________\n"
				+ "    /|  ===  ||  ===  ||  ______________________  |\n"
				+ "   /_|_______||_______||_/    \\________________/  |\n"
				+ "  [_____|                      |               |_/\n"
				+ "        |     /\\_______________|"
			)
		"revolver":
			return (
				"      _________________\n"
				+ "     _/_ _   __________|\n"
				+ "    / / (_) (_)_________)\n"
				+ "   / /   [____]\n"
				+ "  /_/_________________\n"
				+ "     _/_ _   __________|\n"
				+ "    / / (_) (_)_________)\n"
				+ "   / /   [____]\n"
				+ "  /_/"
			)
		"shield":
			return (
				"   .---.\n"
				+ "  / .-. \\\n"
				+ " | | O | |\n"
				+ "  \\ `-' /\n"
				+ "   `---'"
			)
	return ""
