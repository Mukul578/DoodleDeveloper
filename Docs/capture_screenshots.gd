extends SceneTree

const OUTPUT_DIR := "res://Docs/capturas"

var main: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed_scene: PackedScene = load("res://Scenes/Main.tscn")
	main = packed_scene.instantiate()
	root.add_child(main)
	await _frames(8)

	await _capture("01_menu.jpg")

	main.start_game()
	await _frames(30)
	await _capture("02_gameplay.jpg")

	await _simulate_touch_slider()
	await _capture("03_control_slider_invisible.jpg")

	main.pause_game()
	await _frames(8)
	await _capture("04_pausa.jpg")

	main._open_settings_from_pause()
	await _frames(8)
	await _capture("05_configuracion_audio.jpg")

	main._close_settings()
	main.resume_game()
	main._game_over()
	await _frames(8)
	await _capture("06_game_over_record.jpg")

	quit(0)


func _capture(file_name: String) -> void:
	await _frames(2)
	var image := root.get_texture().get_image()
	image.save_jpg("%s/%s" % [OUTPUT_DIR, file_name], 0.86)


func _simulate_touch_slider() -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = Vector2(340.0, 1120.0)
	main._input(touch)

	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(220.0, 1120.0)
	main._input(drag)
	await _frames(12)

	touch.pressed = false
	touch.position = drag.position
	main._input(touch)


func _frames(count: int) -> void:
	for _index in count:
		await process_frame
