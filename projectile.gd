extends Area2D

@export var speed: float = 600.0
@export var damage: int = 1
@export var lifetime: float = 3.0
@export var bullet_color: Color = Color.YELLOW
@export var bullet_color_after_ricochet: Color = Color.GREEN
@export var bullet_length: float = 20.0
@export var bullet_width: float = 6.0
@export var trail_enabled: bool = true
@export var trail_length: float = 30.0
@export var trail_width: float = 3.0
@export var trail_color: Color = Color.YELLOW
@export var trail_color_after_ricochet: Color = Color.GREEN
@export var ricochet_enabled: bool = true
@export var max_ricochets: int = 3
@export var ricochet_speed_loss: float = 0.8
@export var show_impact_effects: bool = true
@export var play_impact_sound: bool = true

var direction: Vector2 = Vector2.RIGHT
var shooter = null
var has_left_shooter: bool = false
var ricochet_count: int = 0
var has_ricocheted: bool = false  # Track if bullet bounced at least once
var trail_line: Line2D = null  # Reference to trail for color change

@onready var impact_sound = $ImpactSound if has_node("ImpactSound") else null

func _ready():
	# IMPORTANT: Make bullet only collide with bodies, not areas
	set_collision_mask_value(1, true)
	set_collision_layer_value(2, true)
	
	# Force connect signals in code
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
		print("Signal connected successfully!")
	
	# Add trail effect
	if trail_enabled:
		trail_line = Line2D.new()
		trail_line.width = trail_width
		trail_line.default_color = trail_color
		trail_line.add_point(Vector2.ZERO)
		trail_line.add_point(Vector2(-trail_length, 0))
		add_child(trail_line)
	
	print("Bullet spawned - Direction: ", direction, " Speed: ", speed)
	
	# Auto-destroy after lifetime expires
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		print("Bullet timeout - destroying")
		queue_free()

func _draw():
	# Use green color after ricochet
	var current_color = bullet_color_after_ricochet if has_ricocheted else bullet_color
	
	draw_rect(Rect2(-bullet_length/2, -bullet_width/2, bullet_length, bullet_width), current_color)
	draw_rect(Rect2(-bullet_length/2, -bullet_width/4, bullet_length, bullet_width/2), Color.WHITE)
	var tip_points = PackedVector2Array([
		Vector2(bullet_length/2, 0),
		Vector2(bullet_length/2 - 5, -bullet_width/2),
		Vector2(bullet_length/2 - 5, bullet_width/2)
	])
	draw_colored_polygon(tip_points, Color.WHITE)

func _physics_process(delta):
	var movement = direction * speed * delta
	position += movement
	
	if shooter and not has_left_shooter:
		var distance = global_position.distance_to(shooter.global_position)
		if distance > 50:
			has_left_shooter = true

func spawn_impact_effect(at_position: Vector2, impact_color: Color = Color.WHITE):
	if not show_impact_effects:
		return
	
	# Create simple impact effect with code
	var impact = Node2D.new()
	impact.global_position = at_position
	
	# Add script to make it animate
	var impact_script = GDScript.new()
	impact_script.source_code = """
extends Node2D

var radius = 5.0
var max_radius = 20.0
var alpha = 1.0
var color = Color.WHITE

func _process(delta):
	radius += 80 * delta
	alpha -= 3.0 * delta
	if alpha <= 0:
		queue_free()
	queue_redraw()

func _draw():
	var c = color
	c.a = alpha
	draw_circle(Vector2.ZERO, radius, c)
	if alpha > 0.5:
		draw_circle(Vector2.ZERO, radius * 0.4, Color.WHITE)
"""
	impact_script.reload()
	impact.set_script(impact_script)
	impact.set("color", impact_color)
	
	get_tree().root.add_child(impact)

func play_impact_sound_effect():
	if not play_impact_sound or not impact_sound:
		return
	
	# Detach sound from bullet so it keeps playing after bullet is destroyed
	if impact_sound.get_parent():
		impact_sound.get_parent().remove_child(impact_sound)
	
	# Add to scene root and play
	get_tree().root.add_child(impact_sound)
	impact_sound.global_position = global_position
	impact_sound.play()
	
	# Auto-delete sound after it finishes
	impact_sound.finished.connect(func(): impact_sound.queue_free())

func _on_body_entered(body):
	print("Bullet collision with: ", body.name, " Type: ", body.get_class())
	print("  Current direction: ", direction)
	
	if shooter and body == shooter and not has_left_shooter:
		print("  -> Ignoring shooter")
		return
	
	if ricochet_enabled and ricochet_count < max_ricochets:
		var is_wall = body.is_in_group("walls") or body is StaticBody2D or body is TileMap
		
		if is_wall:
			print("  -> This is a wall! Attempting ricochet...")
			
			# Notify wall about impact
			if body.has_method("on_bullet_impact"):
				body.on_bullet_impact(global_position)
			
			# Play impact sound
			play_impact_sound_effect()
			
			var space_state = get_world_2d().direct_space_state
			var query = PhysicsRayQueryParameters2D.create(
				global_position - direction * 15,
				global_position + direction * 5
			)
			query.collide_with_areas = false
			query.collide_with_bodies = true
			query.exclude = [shooter] if shooter else []
			
			var result = space_state.intersect_ray(query)
			
			if result and result.collider == body:
				var normal = result.normal
				print("  -> Surface normal: ", normal)
				
				spawn_impact_effect(result.position, Color.YELLOW)
				
				if abs(normal.x) > abs(normal.y):
					direction.x = -direction.x
					print("  -> Hit vertical wall, flipping X")
				else:
					direction.y = -direction.y
					print("  -> Hit horizontal wall, flipping Y")
			else:
				print("  -> Raycast failed, using fallback")
				spawn_impact_effect(global_position, Color.YELLOW)
				
				var to_wall = body.global_position - global_position
				if abs(to_wall.x) > abs(to_wall.y):
					direction.x = -direction.x
				else:
					direction.y = -direction.y
			
			rotation = direction.angle()
			speed *= ricochet_speed_loss
			ricochet_count += 1
			
			# Mark as ricocheted and change color
			if not has_ricocheted:
				has_ricocheted = true
				# Change trail color
				if trail_line:
					trail_line.default_color = trail_color_after_ricochet
				# Redraw bullet with new color
				queue_redraw()
			
			print("  -> RICOCHETED! New direction: ", direction, " Count: ", ricochet_count)
			return
	
	if body.is_in_group("enemies"):
		print("  -> Hit enemy!")
		
		# Check if bullet has ricocheted at least once
		if has_ricocheted:
			print("  -> Bullet ricocheted! Dealing damage")
			spawn_impact_effect(global_position, Color.RED)
			play_impact_sound_effect()
			if body.has_method("take_damage"):
				body.take_damage(damage, global_position)  # Pass bullet position for knockback
		else:
			print("  -> Bullet hasn't ricocheted! No damage")
			spawn_impact_effect(global_position, Color.ORANGE)
			play_impact_sound_effect()
	
	# Play sound and show effect when destroyed
	play_impact_sound_effect()
	spawn_impact_effect(global_position, Color.ORANGE)
	
	print("  -> Destroying bullet")
	queue_free()
