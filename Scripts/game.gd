extends Node2D

const VIEWPORT_SIZE := Vector2(720.0, 1280.0)
const PLATFORM_SCENE := preload("res://Scenes/Platform.tscn")
const START_Y := 1040.0
const PLATFORM_VERTICAL_GAP := Vector2(105.0, 165.0)
const CLEANUP_MARGIN := 180.0
const SCORE_PIXELS_PER_POINT := 10.0

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Camera2D
@onready var platforms_root: Node2D = $Platforms
@onready var menu_layer: CanvasLayer = $UI/MenuLayer
@onready var hud_layer: CanvasLayer = $UI/HUDLayer
@onready var game_over_layer: CanvasLayer = $UI/GameOverLayer
@onready var score_label: Label = $UI/HUDLayer/MarginContainer/ScoreLabel
@onready var final_score_label: Label = $UI/GameOverLayer/Panel/VBoxContainer/FinalScoreLabel
@onready var best_score_label: Label = $UI/GameOverLayer/Panel/VBoxContainer/BestScoreLabel
@onready var jump_sfx: AudioStreamPlayer = $Audio/JumpSFX
@onready var break_sfx: AudioStreamPlayer = $Audio/BreakSFX
@onready var fall_sfx: AudioStreamPlayer = $Audio/FallSFX
@onready var music: AudioStreamPlayer = $Audio/Music

var score := 0
var best_score := 0
var highest_y := START_Y
var score_start_y := START_Y
var next_platform_y := START_Y
var running := false


func _ready() -> void:
	randomize()
	player.viewport_width = VIEWPORT_SIZE.x
	player.bounced.connect(_on_player_bounced)
	$UI/MenuLayer/Panel/VBoxContainer/StartButton.pressed.connect(start_game)
	$UI/GameOverLayer/Panel/VBoxContainer/RetryButton.pressed.connect(start_game)
	$UI/GameOverLayer/Panel/VBoxContainer/MenuButton.pressed.connect(show_main_menu)
	music.finished.connect(_on_music_finished)
	_show_menu()


func _process(_delta: float) -> void:
	if not running:
		return

	_update_camera()
	_update_score()
	_spawn_platforms_until_ready()
	_cleanup_platforms()
	_check_game_over()


func start_game() -> void:
	_clear_platforms()
	score = 0
	score_start_y = START_Y - 90.0
	highest_y = score_start_y
	next_platform_y = START_Y
	camera.position = Vector2(VIEWPORT_SIZE.x * 0.5, VIEWPORT_SIZE.y * 0.5)
	player.reset(Vector2(VIEWPORT_SIZE.x * 0.5, score_start_y))
	_create_starting_platforms()
	score_label.text = "%06d" % score
	_set_ui_state(false, true, false)
	_play_music()
	running = true


func show_main_menu() -> void:
	_clear_platforms()
	camera.position = Vector2(VIEWPORT_SIZE.x * 0.5, VIEWPORT_SIZE.y * 0.5)
	player.position = Vector2(VIEWPORT_SIZE.x * 0.5, START_Y - 90.0)
	_show_menu()


func _show_menu() -> void:
	running = false
	player.stop()
	_set_ui_state(true, false, false)


func _game_over() -> void:
	running = false
	player.stop()
	best_score = max(best_score, score)
	final_score_label.text = "Puntuacion: %d" % score
	best_score_label.text = "Record: %d" % best_score
	_set_ui_state(false, false, true)
	_play_one_shot(fall_sfx)


func _set_ui_state(show_menu: bool, show_hud: bool, show_game_over: bool) -> void:
	menu_layer.visible = show_menu
	hud_layer.visible = show_hud
	game_over_layer.visible = show_game_over


func _create_starting_platforms() -> void:
	_spawn_platform(Vector2(VIEWPORT_SIZE.x * 0.5, START_Y), 0)
	next_platform_y = START_Y - 150.0
	_spawn_platforms_until_ready()


func _spawn_platforms_until_ready() -> void:
	var target_y := camera.position.y - VIEWPORT_SIZE.y * 0.75
	while next_platform_y > target_y:
		var x := randf_range(95.0, VIEWPORT_SIZE.x - 95.0)
		_spawn_platform(Vector2(x, next_platform_y), _choose_platform_type())
		next_platform_y -= randf_range(PLATFORM_VERTICAL_GAP.x, PLATFORM_VERTICAL_GAP.y)


func _spawn_platform(spawn_position: Vector2, type: int) -> void:
	var platform := PLATFORM_SCENE.instantiate()
	platform.position = spawn_position
	platforms_root.add_child(platform)
	if platform.has_method("setup"):
		platform.setup(type)
	if platform.has_signal("broken"):
		platform.broken.connect(_on_platform_broken)


func _choose_platform_type() -> int:
	var roll := randf()
	if score > 70 and roll < 0.16:
		return 2
	if score > 35 and roll < 0.38:
		return 1
	return 0


func _update_camera() -> void:
	var camera_ceiling := camera.position.y - 120.0
	if player.position.y < camera_ceiling:
		camera.position.y = player.position.y + 120.0


func _update_score() -> void:
	highest_y = min(highest_y, player.position.y)
	score = max(score, int((score_start_y - highest_y) / SCORE_PIXELS_PER_POINT))
	score_label.text = "%06d" % score


func _cleanup_platforms() -> void:
	var bottom_limit := camera.position.y + VIEWPORT_SIZE.y * 0.5 + CLEANUP_MARGIN
	for platform in platforms_root.get_children():
		if platform.position.y > bottom_limit:
			platform.queue_free()


func _check_game_over() -> void:
	var bottom_limit := camera.position.y + VIEWPORT_SIZE.y * 0.5 + 120.0
	if player.position.y > bottom_limit:
		_game_over()


func _clear_platforms() -> void:
	for platform in platforms_root.get_children():
		platform.queue_free()


func _on_player_bounced() -> void:
	_play_one_shot(jump_sfx)


func _on_platform_broken() -> void:
	_play_one_shot(break_sfx)


func _play_music() -> void:
	if not music.playing:
		music.play()


func _on_music_finished() -> void:
	if running:
		music.play()


func _play_one_shot(player_node: AudioStreamPlayer) -> void:
	player_node.stop()
	player_node.play()
