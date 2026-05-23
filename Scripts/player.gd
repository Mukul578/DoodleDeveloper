extends CharacterBody2D

signal fell_below_screen

@export var move_speed := 520.0
@export var jump_velocity := -940.0
@export var gravity := 2200.0
@export var viewport_width := 720.0

var active := false
var touch_direction := 0.0


func reset(start_position: Vector2) -> void:
	position = start_position
	velocity = Vector2.ZERO
	active = true
	touch_direction = 0.0


func _physics_process(delta: float) -> void:
	if not active:
		return

	var direction := Input.get_axis("move_left", "move_right")
	if not is_zero_approx(touch_direction):
		direction = touch_direction

	velocity.x = direction * move_speed
	velocity.y += gravity * delta
	var was_falling := velocity.y > 0.0

	move_and_slide()
	_wrap_horizontally()
	_handle_platform_bounce(was_falling)


func bounce(extra_multiplier := 1.0) -> void:
	velocity.y = jump_velocity * extra_multiplier


func stop() -> void:
	active = false
	velocity = Vector2.ZERO
	touch_direction = 0.0


func _wrap_horizontally() -> void:
	var margin := 48.0
	if position.x < -margin:
		position.x = viewport_width + margin
	elif position.x > viewport_width + margin:
		position.x = -margin


func _handle_platform_bounce(was_falling: bool) -> void:
	if not was_falling:
		return

	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		if collision.get_normal().y < -0.65:
			var collider := collision.get_collider()
			if collider != null and collider.has_method("on_player_landed"):
				collider.on_player_landed(self)
			else:
				bounce()
			break
