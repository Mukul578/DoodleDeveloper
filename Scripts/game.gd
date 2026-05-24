extends Node2D

const BASE_VIEWPORT_WIDTH := 720.0
const BASE_VIEWPORT_HEIGHT := 1280.0
# Control tactil por velocidad: cada drag aporta el desplazamiento real del dedo.
# Si el dedo se frena, el desplazamiento baja; si deja de emitir drag, paramos.
const TOUCH_DRAG_DEADZONE := 0.25
const TOUCH_DRAG_FULL_SPEED := 7.0
const TOUCH_STOP_TIMEOUT := 0.07
const PLATFORM_SCENE := preload("res://Scenes/Platform.tscn")
const PLATFORM_NORMAL := 0
const PLATFORM_MOVING := 1
const PLATFORM_BREAKABLE := 2
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
@onready var pause_layer: CanvasLayer = $UI/PauseLayer
@onready var settings_layer: CanvasLayer = $UI/SettingsLayer
@onready var touch_controls: Control = $UI/HUDLayer/TouchControls
@onready var score_label: Label = $UI/HUDLayer/MarginContainer/ScoreLabel
@onready var final_score_label: Label = $UI/GameOverLayer/Panel/VBoxContainer/FinalScoreLabel
@onready var best_score_label: Label = $UI/GameOverLayer/Panel/VBoxContainer/BestScoreLabel
@onready var jump_sfx: AudioStreamPlayer = $Audio/JumpSFX
@onready var break_sfx: AudioStreamPlayer = $Audio/BreakSFX
@onready var fall_sfx: AudioStreamPlayer = $Audio/FallSFX
@onready var normal_platform_sfx: AudioStreamPlayer = $Audio/NormalPlatformSFX
@onready var moving_platform_sfx: AudioStreamPlayer = $Audio/MovingPlatformSFX
@onready var breakable_platform_sfx: AudioStreamPlayer = $Audio/BreakablePlatformSFX
@onready var music: AudioStreamPlayer = $Audio/Music
@onready var music_slider: HSlider = $UI/SettingsLayer/Panel/VBoxContainer/MusicSlider
@onready var effects_slider: HSlider = $UI/SettingsLayer/Panel/VBoxContainer/EffectsSlider

var score := 0
var best_score := 0
var highest_y := START_Y
var score_start_y := START_Y
var next_platform_y := START_Y
var running := false
var paused := false
var _settings_return_layer: CanvasLayer
var _music_volume := 1.0
var _effects_volume := 0.85
var _viewport_size := Vector2(BASE_VIEWPORT_WIDTH, BASE_VIEWPORT_HEIGHT)
var _active_touch_index := -1
var _touch_idle_time := 0.0


func _ready() -> void:
	randomize()
	_refresh_viewport_size()
	$UI/MenuLayer/Panel/VBoxContainer/StartButton.pressed.connect(start_game)
	$UI/MenuLayer/Panel/VBoxContainer/SettingsButton.pressed.connect(_open_settings_from_menu)
	$UI/HUDLayer/PauseButton.pressed.connect(pause_game)
	$UI/GameOverLayer/Panel/VBoxContainer/RetryButton.pressed.connect(start_game)
	$UI/GameOverLayer/Panel/VBoxContainer/MenuButton.pressed.connect(show_main_menu)
	$UI/PauseLayer/Panel/VBoxContainer/ResumeButton.pressed.connect(resume_game)
	$UI/PauseLayer/Panel/VBoxContainer/PauseSettingsButton.pressed.connect(_open_settings_from_pause)
	$UI/PauseLayer/Panel/VBoxContainer/PauseMenuButton.pressed.connect(show_main_menu)
	$UI/SettingsLayer/Panel/VBoxContainer/SettingsBackButton.pressed.connect(_close_settings)
	music_slider.value_changed.connect(_on_music_volume_changed)
	effects_slider.value_changed.connect(_on_effects_volume_changed)
	music.finished.connect(_on_music_finished)
	_apply_volume_settings()
	_show_menu()


func _input(event: InputEvent) -> void:
	if not running or paused:
		return

	# Un unico dedo controla al jugador. Mientras este pulsado, cada drag actualiza
	# la direccion segun el movimiento instantaneo del dedo, no segun una zona fija.
	if event is InputEventScreenTouch:
		if event.pressed and _active_touch_index == -1:
			_active_touch_index = event.index
			_touch_idle_time = 0.0
			player.touch_direction = 0.0
		elif not event.pressed and event.index == _active_touch_index:
			_active_touch_index = -1
			_touch_idle_time = 0.0
			player.touch_direction = 0.0
	elif event is InputEventScreenDrag and event.index == _active_touch_index:
		_touch_idle_time = 0.0
		_update_touch_drag_direction(event.relative.x)


func _process(delta: float) -> void:
	_refresh_viewport_size()
	if not running or paused:
		return

	_stop_touch_when_finger_stops(delta)
	_update_camera()
	_update_score()
	_spawn_platforms_until_ready()
	_cleanup_platforms()
	_check_game_over()


func start_game() -> void:
	get_tree().paused = false
	paused = false
	_clear_platforms()
	score = 0
	score_start_y = START_Y - 90.0
	highest_y = score_start_y
	next_platform_y = START_Y
	_refresh_viewport_size()
	camera.position = Vector2(_viewport_size.x * 0.5, _viewport_size.y * 0.5)
	player.reset(Vector2(_viewport_size.x * 0.5, score_start_y))
	_create_starting_platforms()
	score_label.text = "%06d" % score
	_set_ui_state(false, true, false, false, false)
	_play_music()
	running = true


func show_main_menu() -> void:
	get_tree().paused = false
	paused = false
	_clear_platforms()
	_refresh_viewport_size()
	camera.position = Vector2(_viewport_size.x * 0.5, _viewport_size.y * 0.5)
	player.position = Vector2(_viewport_size.x * 0.5, START_Y - 90.0)
	_show_menu()


func pause_game() -> void:
	if not running or paused:
		return
	paused = true
	pause_layer.visible = true
	touch_controls.visible = false
	_active_touch_index = -1
	_touch_idle_time = 0.0
	player.touch_direction = 0.0
	Input.action_release("move_left")
	Input.action_release("move_right")
	get_tree().paused = true


func resume_game() -> void:
	if not paused:
		return
	get_tree().paused = false
	paused = false
	pause_layer.visible = false
	touch_controls.visible = true


func _show_menu() -> void:
	running = false
	_active_touch_index = -1
	_touch_idle_time = 0.0
	player.stop()
	_set_ui_state(true, false, false, false, false)


func _game_over() -> void:
	get_tree().paused = false
	paused = false
	running = false
	player.stop()
	best_score = max(best_score, score)
	final_score_label.text = "Puntuacion: %d" % score
	best_score_label.text = "Record: %d" % best_score
	_set_ui_state(false, false, true, false, false)
	_play_one_shot(fall_sfx)


func _set_ui_state(show_menu: bool, show_hud: bool, show_game_over: bool, show_pause: bool, show_settings: bool) -> void:
	menu_layer.visible = show_menu
	hud_layer.visible = show_hud
	game_over_layer.visible = show_game_over
	pause_layer.visible = show_pause
	settings_layer.visible = show_settings
	touch_controls.visible = show_hud and not show_pause and not show_settings


func _create_starting_platforms() -> void:
	# La primera plataforma siempre queda centrada bajo el jugador.
	_spawn_platform(Vector2(_viewport_size.x * 0.5, START_Y), 0)
	next_platform_y = START_Y - 150.0
	_spawn_platforms_until_ready()


func _spawn_platforms_until_ready() -> void:
	# Generamos plataformas por encima de la camara antes de que entren en pantalla.
	var target_y := camera.position.y - _viewport_size.y * 0.75
	while next_platform_y > target_y:
		var x := randf_range(95.0, _viewport_size.x - 95.0)
		_spawn_platform(Vector2(x, next_platform_y), _choose_platform_type())
		next_platform_y -= randf_range(PLATFORM_VERTICAL_GAP.x, PLATFORM_VERTICAL_GAP.y)


func _spawn_platform(spawn_position: Vector2, type: int) -> void:
	var platform := PLATFORM_SCENE.instantiate()
	platform.position = spawn_position
	platforms_root.add_child(platform)
	if platform.has_method("setup"):
		platform.setup(type)
	if platform.has_signal("landed"):
		platform.landed.connect(_on_platform_landed)
	if platform.has_signal("broken"):
		platform.broken.connect(_on_platform_broken)


func _choose_platform_type() -> int:
	var roll := randf()
	if score > 70 and roll < 0.16:
		return PLATFORM_BREAKABLE
	if score > 35 and roll < 0.38:
		return PLATFORM_MOVING
	return PLATFORM_NORMAL


func _update_camera() -> void:
	camera.position.x = _viewport_size.x * 0.5
	# La camara solo sube; nunca baja si el jugador cae.
	var camera_ceiling := camera.position.y - 120.0
	if player.position.y < camera_ceiling:
		camera.position.y = player.position.y + 120.0


func _update_score() -> void:
	# La puntuacion usa la mejor altura alcanzada, no la posicion actual al caer.
	highest_y = min(highest_y, player.position.y)
	score = max(score, int((score_start_y - highest_y) / SCORE_PIXELS_PER_POINT))
	score_label.text = "%06d" % score


func _cleanup_platforms() -> void:
	var bottom_limit := camera.position.y + _viewport_size.y * 0.5 + CLEANUP_MARGIN
	for platform in platforms_root.get_children():
		if platform.position.y > bottom_limit:
			platform.queue_free()


func _check_game_over() -> void:
	var bottom_limit := camera.position.y + _viewport_size.y * 0.5 + 120.0
	if player.position.y > bottom_limit:
		_game_over()


func _clear_platforms() -> void:
	for platform in platforms_root.get_children():
		platform.queue_free()


func _on_platform_landed(platform_type: int) -> void:
	match platform_type:
		PLATFORM_NORMAL:
			_play_one_shot(normal_platform_sfx)
		PLATFORM_MOVING:
			_play_one_shot(moving_platform_sfx)
		PLATFORM_BREAKABLE:
			_play_one_shot(breakable_platform_sfx)
		_:
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


func _open_settings_from_menu() -> void:
	_settings_return_layer = menu_layer
	menu_layer.visible = false
	settings_layer.visible = true


func _open_settings_from_pause() -> void:
	_settings_return_layer = pause_layer
	pause_layer.visible = false
	settings_layer.visible = true


func _close_settings() -> void:
	settings_layer.visible = false
	if _settings_return_layer != null:
		_settings_return_layer.visible = true
	else:
		menu_layer.visible = true


func _on_music_volume_changed(value: float) -> void:
	_music_volume = value
	_apply_volume_settings()


func _on_effects_volume_changed(value: float) -> void:
	_effects_volume = value
	_apply_volume_settings()


func _apply_volume_settings() -> void:
	# Los sliders guardan valores lineales 0..1, Godot reproduce audio en decibelios.
	music.volume_db = _linear_to_db(_music_volume, -4.0)
	for sfx in [jump_sfx, break_sfx, fall_sfx, normal_platform_sfx, moving_platform_sfx, breakable_platform_sfx]:
		sfx.volume_db = _linear_to_db(_effects_volume, -6.0)


func _linear_to_db(value: float, base_db: float) -> float:
	if value <= 0.0:
		return -80.0
	return base_db + linear_to_db(value)


func _refresh_viewport_size() -> void:
	# En movil hay muchas relaciones de aspecto; usamos el viewport real del dispositivo.
	_viewport_size = get_viewport_rect().size
	if _viewport_size.x <= 0.0 or _viewport_size.y <= 0.0:
		_viewport_size = Vector2(BASE_VIEWPORT_WIDTH, BASE_VIEWPORT_HEIGHT)
	player.viewport_width = _viewport_size.x
	camera.position.x = _viewport_size.x * 0.5


func _update_touch_drag_direction(relative_x: float) -> void:
	if absf(relative_x) <= TOUCH_DRAG_DEADZONE:
		player.touch_direction = 0.0
	else:
		player.touch_direction = clampf(relative_x / TOUCH_DRAG_FULL_SPEED, -1.0, 1.0)


func _stop_touch_when_finger_stops(delta: float) -> void:
	if _active_touch_index == -1 or is_zero_approx(player.touch_direction):
		return
	_touch_idle_time += delta
	if _touch_idle_time > TOUCH_STOP_TIMEOUT:
		player.touch_direction = 0.0
