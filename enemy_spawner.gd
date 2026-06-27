extends Node2D

const MELEE_SCENE: PackedScene = preload("res://enemy.tscn")
const SHOOTING_SCENE: PackedScene = preload("res://shooting_enemy.tscn")

const CORNERS: Array = [
	Vector2(200, 200),
	Vector2(2300, 200),
	Vector2(200, 1900),
	Vector2(2300, 1900),
]

const SPAWN_POINTS: Array = [
	Vector2(200, 200),
	Vector2(2300, 200),
	Vector2(200, 1900),
	Vector2(2300, 1900),
	Vector2(1250, 200),
	Vector2(200, 1050),
	Vector2(2300, 1050),
	Vector2(1250, 1900),
]

const BOSS_TIMER_MAX: float = 60.0

var _wave_timer: float = 12.0
var _level_up_player: AudioStreamPlayer
var _boss_timer: float = BOSS_TIMER_MAX
var _boss_spawned: bool = false
var _boss_node: Node = null
var _wave_number: int = 0

func _ready() -> void:
	_level_up_player = AudioStreamPlayer.new()
	add_child(_level_up_player)
	_level_up_player.stream = load("res://Audio/level_up.mp3")

func _physics_process(delta):
	var hud = get_tree().get_first_node_in_group("hud")
	# Boss countdown
	if not _boss_spawned:
		_boss_timer -= delta
		if hud and hud.has_method("update_boss_timer"):
			hud.update_boss_timer(_boss_timer / BOSS_TIMER_MAX, maxf(_boss_timer, 0.0))
		if _boss_timer <= 0.0:
			_boss_spawned = true
			if hud and hud.has_method("hide_boss_timer"):
				hud.hide_boss_timer()
			_spawn_boss()
	elif is_instance_valid(_boss_node):
		if _boss_node.is_dead:
			_boss_node = null
			if hud and hud.has_method("show_boss_reward"):
				hud.show_boss_reward()
		elif hud and hud.has_method("update_boss_hp"):
			var frac := float(_boss_node.current_health) / float(_boss_node.max_health)
			hud.update_boss_hp(frac, _boss_node.current_health)

	# Wave timer — fires every 15 seconds regardless of living enemies
	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_wave_timer = 12.0
		_spawn_wave()

func _spawn_boss() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var points := SPAWN_POINTS.duplicate()
	points.shuffle()
	var spawn_pt: Vector2 = points[0]
	for p in points:
		if not player or p.distance_to(player.global_position) > 300:
			spawn_pt = p
			break
	var boss = MELEE_SCENE.instantiate()
	boss.max_health = 50
	get_parent().add_child(boss)
	boss.global_position = spawn_pt
	boss.make_boss()
	_boss_node = boss


func _spawn_wave() -> void:
	_wave_number += 1
	_level_up_player.play()
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_wave_title"):
		hud.show_wave_title()
	var player = get_tree().get_first_node_in_group("player")

	# Sort corners farthest-first from player
	var corners := CORNERS.duplicate()
	if player:
		corners.sort_custom(func(a, b):
			return a.distance_to(player.global_position) > b.distance_to(player.global_position))

	# 2, 4, 8, 16… enemies — cycle through corners
	var count := int(pow(2, _wave_number))
	for i in count:
		var melee = MELEE_SCENE.instantiate()
		melee.global_position = corners[i % corners.size()]
		get_parent().add_child(melee)
