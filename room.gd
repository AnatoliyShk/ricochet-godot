extends Node2D

const ROOM_TL := Vector2(70, 70)
const ROOM_BR := Vector2(2430, 2030)
const ROOM_LEFT  := 0.0
const ROOM_TOP   := 0.0
const ROOM_RIGHT := 2500.0
const ROOM_BOT   := 2100.0

var _floor_tex: ImageTexture
var _tile_w: float = 0.0
var _tile_h: float = 0.0
var _last_cam_pos := Vector2(INF, INF)

func _ready():
	var tex := load("res://Objects/floor_tile_1.png") as Texture2D
	_floor_tex = ImageTexture.create_from_image(tex.get_image())
	_tile_w = float(_floor_tex.get_width()) * 1.0
	_tile_h = float(_floor_tex.get_height()) * 1.0
	await get_tree().process_frame
	_build_nav_mesh()
	_start_music()
	queue_redraw()

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.global_position.distance_to(_last_cam_pos) > 1.0:
		_last_cam_pos = cam.global_position
		queue_redraw()

func _draw() -> void:
	if not _floor_tex:
		return
	var tw := _tile_w
	var th := _tile_h

	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	var vp_size := get_viewport_rect().size / cam.zoom
	var cam_pos := cam.global_position
	var pad := Vector2(tw * 2.0, th * 2.0)
	var vis_tl := cam_pos - vp_size * 0.5 - pad
	var vis_br := cam_pos + vp_size * 0.5 + pad

	var c0 := int(floor(vis_tl.x / tw))
	var r0 := int(floor(vis_tl.y / th))
	var c1 := int(ceil(vis_br.x / tw))
	var r1 := int(ceil(vis_br.y / th))

	var half := Vector2(tw * 0.5, th * 0.5)
	var tile_rect := Rect2(-half, Vector2(tw, th))

	for r in range(r0, r1):
		for c in range(c0, c1):
			var center := Vector2(c * tw + half.x, r * th + half.y)
			var rot: float = (abs(hash(Vector2i(c + 999, r + 999))) % 4) * PI * 0.5
			draw_set_transform(center, rot, Vector2.ONE)
			draw_texture_rect(_floor_tex, tile_rect, false)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Black mask outside room bounds
	var big := 8000.0
	var black := Color(0.0, 0.0, 0.0, 1.0)
	draw_rect(Rect2(-big,       -big,       ROOM_RIGHT + big * 2.0, big),           black)
	draw_rect(Rect2(-big,       ROOM_BOT,   ROOM_RIGHT + big * 2.0, big),           black)
	draw_rect(Rect2(-big,       ROOM_TOP,   big,                    ROOM_BOT),      black)
	draw_rect(Rect2(ROOM_RIGHT, ROOM_TOP,   big,                    ROOM_BOT),      black)

func _start_music() -> void:
	var music_player := AudioStreamPlayer.new()
	add_child(music_player)
	var _osts := ["res://Audio/ost_1.mp3", "res://Audio/ost_2.mp3", "res://Audio/ost_3.mp3"]
	var stream := load(_osts[randi() % _osts.size()]) as AudioStreamMP3
	stream.loop = true
	music_player.stream = stream
	music_player.pitch_scale = 1.0
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.add_to_group("music")
	music_player.play()

func _build_nav_mesh() -> void:
	var nav_region: NavigationRegion2D = $NavigationRegion2D
	var poly: NavigationPolygon = nav_region.navigation_polygon
	var source_geo := NavigationMeshSourceGeometryData2D.new()

	# Outer walkable boundary — clockwise in screen-space (y-down)
	source_geo.add_traversable_outline(PackedVector2Array([
		ROOM_TL,
		Vector2(ROOM_BR.x, ROOM_TL.y),
		ROOM_BR,
		Vector2(ROOM_TL.x, ROOM_BR.y),
	]))

	# Carve holes for walls that overlap the room
	var room_rect := Rect2(ROOM_TL, ROOM_BR - ROOM_TL)
	for wall in get_tree().get_nodes_in_group("walls"):
		_add_wall_hole(source_geo, wall, room_rect)

	NavigationServer2D.bake_from_source_geometry_data(poly, source_geo)
	nav_region.navigation_polygon = poly

func _add_wall_hole(source_geo: NavigationMeshSourceGeometryData2D, wall: Node, room_rect: Rect2) -> void:
	for child in wall.get_children():
		if not (child is CollisionShape2D):
			continue
		if not (child.shape is RectangleShape2D):
			continue

		var half := (child.shape as RectangleShape2D).size / 2.0
		var xf: Transform2D = child.global_transform

		var c0 := xf * Vector2(-half.x, -half.y)
		var c1 := xf * Vector2( half.x, -half.y)
		var c2 := xf * Vector2( half.x,  half.y)
		var c3 := xf * Vector2(-half.x,  half.y)

		var min_pt := Vector2(min(c0.x, min(c1.x, min(c2.x, c3.x))),
							  min(c0.y, min(c1.y, min(c2.y, c3.y))))
		var max_pt := Vector2(max(c0.x, max(c1.x, max(c2.x, c3.x))),
							  max(c0.y, max(c1.y, max(c2.y, c3.y))))

		if not room_rect.intersects(Rect2(min_pt, max_pt - min_pt)):
			continue

		# Counter-clockwise in screen-space = obstacle hole
		source_geo.add_obstruction_outline(PackedVector2Array([c0, c3, c2, c1]))
