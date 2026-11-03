extends Node
## Скриншоты текущей сборки «ПАЛАТА 13» для проверки этапа.
## Запуск: godot --path . --resolution 1280x720 -- --capture-stage2

var main: Node


func _ready() -> void:
	main = get_parent()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures/palata"))
	await get_tree().create_timer(1.0).timeout
	await _shot("01_menu")

	main._request_new_game()
	await _wait(0.6)
	await _shot("02_difficulty")
	main.ui.difficulty_ui._cancel()
	await _wait(0.3)

	Game.set_difficulty(1)
	main._on_new_game()
	await _wait(0.8)
	main.ui.close_modals()
	await _wait(0.5)
	await _shot("03_ward13")

	var w: World = main.world
	w.player.teleport(Vector2(20 * 32, 13.5 * 32))
	await _wait(0.7)
	await _shot("04_corridor")

	w.spawn_doctor()
	await _wait(0.4)
	if w.doctor != null:
		w.doctor.global_position = w.player.global_position + Vector2(190, -30)
	await _wait(0.8)
	await _shot("05_doctor")

	main.ui.show_dialog("doctor_first")
	await _wait(0.8)
	await _shot("06_dialog")
	main.ui.close_modals()

	Game.add_item("key_ward")
	Game.add_item("battery")
	Game.add_note("Дневник Ирины Соколовой", "«13-я палата — это не номер. Это те, кого он не отпустил».")
	main.ui.toggle_inventory("items")
	await _wait(0.6)
	await _shot("07_inventory")
	main.ui.toggle_inventory("journal")
	await _wait(0.5)
	await _shot("08_journal")
	main.ui.close_modals()

	main.ui.show_note("Дневник Ирины Соколовой",
		"«12 апреля. Доктор снова не подписал выписку. Говорит: дети ещё не готовы.\nЕсли со мной что-то случится, Миша, код от аптечного сейфа — день и месяц, когда ты родился».")
	await _wait(0.5)
	await _shot("09_note")
	main.ui.close_modals()

	main.ui.show_ending("escape")
	await _wait(0.7)
	await _shot("10_ending")
	main.ui.close_modals()

	main.ui.show_death()
	await _wait(0.5)
	await _shot("11_death")
	main.ui.close_modals()

	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://captures/palata/%s.png" % name)
	var err := img.save_png(path)
	print("CAPTURE %s -> err=%d" % [name, err])
