extends Node
## Снимает набор скриншотов игры для проверки: меню, этажи, диалоги, интерфейс, финалы.
## Запуск: godot --path . -- --capture

var main: Node


func _ready() -> void:
	main = get_parent()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	await get_tree().create_timer(1.2).timeout
	var bg: TextureRect = main.ui.menu._bg
	print("DIAG menu_bg size=%s tex=%s" % [str(bg.size), str(bg.texture)])
	await _shot("01_menu")
	await _run()
	get_tree().quit()


func _run() -> void:
	# --- окно выбора сложности
	main._request_new_game()
	await _wait(0.8)
	await _shot("01b_difficulty")
	main.ui.difficulty_ui._cancel()
	await _wait(0.3)

	# --- настройки: громкость и полный экран
	main.ui.menu._show_settings(false)
	await _wait(0.5)
	await _shot("01c_settings")
	main.ui.menu._close_settings()
	await _wait(0.3)

	# --- Г5: лазарет
	main._on_new_game()
	await _wait(0.6)
	# без вступительных диалогов — чтобы видеть сами этажи
	for f in ["B5", "B4", "B3", "B2"]:
		Game.set_flag("intro:%s" % f)
	main.load_floor(0)
	await _wait(0.4)
	main.ui.close_modals()
	await _wait(1.2)
	await _shot("02_g5_lazaret")

	# хозяин этажа B5 крупным планом + диалог
	_focus_npc("grisha")
	await _wait(0.9)
	await _shot("03_host_grisha")
	main.ui.show_dialog("grisha_first")
	await _wait(1.1)
	await _shot("04_dialog_grisha")
	main.ui.close_modals()
	await _wait(0.3)

	# --- интерфейс
	Game.add_item("medkit")
	Game.add_item("key_ward")
	Game.add_item("scythe")
	Game.add_item("note")
	Game.add_note("Журнал процедур", "Палата 3. Пациент №11: голоса из вентиляции.")
	main.ui.toggle_inventory("items")
	await _wait(0.8)
	await _shot("05_inventory")
	main.ui.toggle_inventory("journal")
	await _wait(0.6)
	await _shot("06_journal")
	main.ui.close_modals()
	await _wait(0.3)

	main.ui.toggle_map()
	await _wait(0.6)
	await _shot("07_map")
	main.ui.close_modals()
	await _wait(0.3)

	main.ui.show_pause()
	await _wait(0.5)
	await _shot("08_pause")
	main.ui.close_modals()
	await _wait(0.3)

	# --- остальные этажи
	var labels := {"1": "G4_mogilnik", "2": "G3_sortirovka", "3": "G2_molelnya"}
	for floor_index in [1, 2, 3]:
		main.load_floor(floor_index)
		await _wait(1.6)
		await _shot("%02d_%s" % [8 + floor_index, labels[str(floor_index)]])

	# --- хозяева остальных этажей
	var hosts := {"1": "tikhon", "2": "zoya", "3": "dispatcher"}
	for floor_index in [1, 2, 3]:
		main.load_floor(floor_index)
		await _wait(1.2)
		_focus_npc(hosts[str(floor_index)])
		await _wait(0.8)
		await _shot("12_host_%s" % hosts[str(floor_index)])

	# --- пульт и финал на Г2
	Game.set_flag("b2_candles_lit")
	main.load_floor(3)
	await _wait(1.2)
	main.ui.show_dialog("b2_altar")
	await _wait(0.9)
	await _shot("13_altar_dialog")
	main.ui.close_modals()

	main.ui.show_ending("together")
	await _wait(0.8)
	await _shot("14_ending")
	main.ui.close_modals()

	main.ui.show_death()
	await _wait(0.6)
	await _shot("15_death")
	main.ui.close_modals()


func _focus_npc(who: String) -> void:
	if main.world == null or not is_instance_valid(main.world):
		return
	for it in main.world.get_tree().get_nodes_in_group("interactables"):
		if it is Interactable and it.kind == "npc" and str(it.data.get("who", "")) == who:
			main.world.player.teleport(it.global_position + Vector2(0, 46))
			return


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://captures/%s.png" % name)
	var err := img.save_png(path)
	print("CAPTURE %s -> err=%d" % [name, err])

