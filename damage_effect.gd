extends CanvasLayer

var _material: ShaderMaterial
var _tween: Tween
var _time: float = 0.0

func _ready():
	layer = 11
	add_to_group("damage_effect")

	var rect = ColorRect.new()
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(0, 0, 0, 0)

	_material = ShaderMaterial.new()
	_material.shader = load("res://damage_effect.gdshader")
	_material.set_shader_parameter("intensity", 0.0)
	_material.set_shader_parameter("time_offset", 0.0)
	rect.material = _material
	add_child(rect)


func _process(delta: float):
	_time += delta
	if _material:
		_material.set_shader_parameter("time_offset", _time)


func trigger():
	if _tween:
		_tween.kill()

	_set_intensity(1.0)

	_tween = create_tween()
	_tween.tween_method(_set_intensity, 1.0, 0.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)


func _set_intensity(t: float):
	if _material:
		_material.set_shader_parameter("intensity", t)
