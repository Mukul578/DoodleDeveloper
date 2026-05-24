extends CharacterBody2D

signal fell_below_screen
@export var move_speed := 520.0
@export var jump_velocity := -940.0
@export var gravity := 2200.0
@export var viewport_width := 720.0

@onready var visual_root: Node2D = $VisualRoot

var active := false
var touch_direction := 0.0
var _visual_tween: Tween
var _falling_pose := false


func reset(start_position: Vector2) -> void:
	position = start_position
	velocity = Vector2.ZERO
	active = true
	touch_direction = 0.0
	_reset_visual_pose()


func _physics_process(delta: float) -> void:
	if not active:
		return

	# Teclado para probar en PC; en movil touch_direction lo sobreescribe.
	var direction := Input.get_axis("move_left", "move_right")
	if not is_zero_approx(touch_direction):
		direction = touch_direction

	# El eje X lo decide la entrada y el eje Y siempre aplica gravedad.
	velocity.x = direction * move_speed
	velocity.y += gravity * delta
	var was_falling := velocity.y > 0.0

	move_and_slide()
	_wrap_horizontally()
	_handle_platform_bounce(was_falling)
	_update_air_pose()


func bounce(extra_multiplier := 1.0) -> void:
	velocity.y = jump_velocity * extra_multiplier
	_play_jump_animation()


func stop() -> void:
	active = false
	velocity = Vector2.ZERO
	touch_direction = 0.0
	_reset_visual_pose()


func _wrap_horizontally() -> void:
	# Como en Doodle Jump: salir por un lado devuelve al jugador por el contrario.
	var margin := 48.0
	if position.x < -margin:
		position.x = viewport_width + margin
	elif position.x > viewport_width + margin:
		position.x = -margin


func _handle_platform_bounce(was_falling: bool) -> void:
	if not was_falling:
		return

	# Solo rebotamos si la colision viene desde arriba de la plataforma.
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		if collision.get_normal().y < -0.65:
			var collider := collision.get_collider()
			if collider != null and collider.has_method("on_player_landed"):
				collider.on_player_landed(self)
			else:
				bounce()
			break


func _update_air_pose() -> void:
	# La animacion se basa en el estado vertical: subiendo o cayendo.
	if velocity.y > 90.0:
		if not _falling_pose:
			_falling_pose = true
			_tween_visual(Vector2(1.06, 0.94), Vector2(0.0, 4.0), 0.16)
	elif velocity.y < -90.0:
		_falling_pose = false
		if _visual_tween == null or not _visual_tween.is_running():
			_tween_visual(Vector2(0.92, 1.10), Vector2(0.0, -4.0), 0.12)


func _play_jump_animation() -> void:
	# Squash and stretch: comprime al tocar y estira al salir del salto.
	_falling_pose = false
	if _visual_tween != null:
		_visual_tween.kill()

	visual_root.scale = Vector2(1.18, 0.82)
	visual_root.position = Vector2(0.0, 8.0)
	_visual_tween = create_tween()
	_visual_tween.tween_property(visual_root, "scale", Vector2(0.86, 1.16), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_visual_tween.parallel().tween_property(visual_root, "position", Vector2(0.0, -6.0), 0.08)
	_visual_tween.tween_property(visual_root, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_visual_tween.parallel().tween_property(visual_root, "position", Vector2.ZERO, 0.14)


func _tween_visual(target_scale: Vector2, target_position: Vector2, duration: float) -> void:
	if _visual_tween != null:
		_visual_tween.kill()
	_visual_tween = create_tween()
	_visual_tween.tween_property(visual_root, "scale", target_scale, duration)
	_visual_tween.parallel().tween_property(visual_root, "position", target_position, duration)


func _reset_visual_pose() -> void:
	_falling_pose = false
	if _visual_tween != null:
		_visual_tween.kill()
	visual_root.scale = Vector2.ONE
	visual_root.position = Vector2.ZERO
