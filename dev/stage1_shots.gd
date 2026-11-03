extends Node
## Быстрый набор скриншотов первого этапа: титул, четыре горизонта, портреты.
## Запуск: godot --path . -- --stage1-shots

var main: Node

func _ready() -> void:
	main = get_parent()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures/stage1"))
	await _wait(0.8)
	await _shot("01_menu")
	main._request_new_game()
	await _wait(0.5)
	await _shot("01b_difficulty")
	main.ui.difficulty_ui._cancel()
	await _wait(0.3)
	main._on_new_game()
	await _wait(0.5)
	for f in ["B5", "B4", "B3", "B2"]:
		Game.set_flag("intro:%s" % f)
	main.load_floor(0)
	await _wait(1.0)
	main.ui.close_modals()
	await _wait(0.3)
	await _shot("02_g5_lazaret")
	main.ui.show_dialog("grisha_first")
	await _wait(0.7)
	await _shot("03_grisha_dialog")
	main.ui.close_modals()
	main.load_floor(1)
	await _wait(1.0)
	await _shot("04_g4_mogilnik")
	main.ui.show_dialog("tikhon_first")
	await _wait(0.6)
	await _shot("05_tikhon_dialog")
	main.ui.close_modals()
	main.load_floor(2)
	await _wait(1.0)
	await _shot("06_g3_sortirovka")
	main.ui.show_dialog("zoya_trial")
	await _wait(0.6)
	await _shot("07_zoya_dialog")
	main.ui.close_modals()
	main.load_floor(3)
	await _wait(1.0)
	await _shot("08_g2_molelnya")
	main.ui.show_dialog("dispatcher_first")
	await _wait(0.6)
	await _shot("09_dispatcher_dialog")
	main.ui.close_modals()
	main.ui.show_floor_transition({
		"rank": "S", "floor": "НАСОСНАЯ", "time": 104.0, "notes": 4, "notes_need": 4,
		"time_ok": true, "notes_ok": true, "no_death": true, "clean": true,
	}, 1)
	await _wait(0.5)
	await _shot("11_transition")
	main.ui.transition.visible = false
	main.ui.show_ending("together")
	await _wait(0.8)
	await _shot("10_ending")
	get_tree().quit()

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.get_width() > 1600:
		img.resize(1600, int(float(img.get_height()) * 1600.0 / float(img.get_width())), Image.INTERPOLATE_LANCZOS)
	var path := ProjectSettings.globalize_path("res://captures/stage1/%s.png" % name)
	print("STAGE1 %s -> %d" % [name, img.save_png(path)])
