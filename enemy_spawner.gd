extends Node2D

const MELEE_SCENE: PackedScene = preload("res://enemy.tscn")
const SHOOTING_SCENE: PackedScene = preload("res://shooting_enemy.tscn")

const SPAWN_POINTS: Array = [
	Vector2(150, 150),
	Vector2(1050, 150),
	Vector2(150, 800),
	Vector2(1050, 800),
	Vector2(600, 120),
	Vector2(120, 500),
	Vector2(1080, 500),
]

var _check_timer: float = 1.5  # initial delay so placed enemies have time to register

func _physics_process(delta):
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = 1.0
	if get_tree().get_nodes_in_group("enemies").size() == 0:
		_spawn_wave()


func _spawn_wave() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var points := SPAWN_POINTS.duplicate()
	points.shuffle()

	var valid: Array = []
	for p in points:
		if not player or p.distance_to(player.global_position) > 220:
			valid.append(p)
	if valid.size() < 2:
		valid = points

	var melee = MELEE_SCENE.instantiate()
	melee.global_position = valid[0]
	get_parent().add_child(melee)

	var shooter = SHOOTING_SCENE.instantiate()
	shooter.global_position = valid[1]
	get_parent().add_child(shooter)
