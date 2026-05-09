extends Node2D

const ROOM_TL := Vector2(70, 70)
const ROOM_BR := Vector2(1130, 930)

func _ready():
	await get_tree().process_frame
	_build_nav_mesh()

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
