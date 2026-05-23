extends AnimatableBody2D

enum PlatformType { NORMAL, MOVING, BREAKABLE }

@export var platform_type := PlatformType.NORMAL
@export var move_distance := 150.0
@export var move_speed := 90.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _start_x := 0.0
var _phase := 0.0
var _broken := false


func setup(type: int) -> void:
	platform_type = type
	_apply_visuals()


func _ready() -> void:
	_start_x = position.x
	_phase = randf() * TAU
	_apply_visuals()


func _physics_process(delta: float) -> void:
	if platform_type != PlatformType.MOVING or _broken:
		return

	_phase += delta * move_speed / max(move_distance, 1.0)
	position.x = _start_x + sin(_phase) * move_distance


func on_player_landed(player: Node) -> void:
	if _broken:
		return

	if platform_type == PlatformType.BREAKABLE:
		if player.has_method("bounce"):
			player.bounce()
		_break()
		return

	if player.has_method("bounce"):
		player.bounce()


func _break() -> void:
	_broken = true
	collision_shape.set_deferred("disabled", true)
	if sprite != null:
		sprite.modulate = Color(1.0, 0.55, 0.45, 0.65)
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y + 90.0, 0.22)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.22)
	tween.tween_callback(queue_free)


func _apply_visuals() -> void:
	if sprite == null:
		return

	match platform_type:
		PlatformType.NORMAL:
			sprite.texture = preload("res://Assets/Sprites/platform_normal.png")
			sprite.modulate = Color.WHITE
		PlatformType.MOVING:
			sprite.texture = preload("res://Assets/Sprites/platform_moving.png")
			sprite.modulate = Color.WHITE
		PlatformType.BREAKABLE:
			sprite.texture = preload("res://Assets/Sprites/platform_breakable.png")
			sprite.modulate = Color.WHITE
