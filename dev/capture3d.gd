extends Node
## Снимает кадры 3D-режима для проверки: зал, комнаты, записка, пауза, Хозяйка, финалы.
## Запуск: godot --path . --rendering-driver opengl3 res://scenes/House3D.tscn -- --capture-3d

const OUT := "res://captures/3d"

var game: Node
var _dir := ""


func setup(g: Node) -> void:
	game = g
	_dir = ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(_dir)
	_run()


func _run() -> void:
	await _wait(1.0)
	await _shot("01_intro")

	await _wait(4.2)
	await _shot("02_hall")

	_look(Vector2(0.0, 5.4), 180.0)
	await _wait(0.5)
	await _shot("03_entry_from_inside")

	_look(Vector2(0.0, 1.5), 0.0)
	await _wait(0.5)
	await _shot("04_foyer")

	_look(Vector2(6.2, 0.6), 250.0)
	await _wait(0.5)
	await _shot("05_room_right")

	_look(Vector2(-6.6, 0.8), 120.0)
	await _wait(0.5)
	await _shot("06_room_left")

	# фонарь выключен — проверяем темноту
	game.player.toggle_flashlight()
	await _wait(0.4)
	await _shot("07_dark")
	game.player.toggle_flashlight()
	await _wait(0.3)

	# печать крупным планом
	var seal_pos := _find_first("seal")
	if seal_pos != Vector3.ZERO:
		game.player.teleport_to(Vector3(seal_pos.x, seal_pos.y - 0.08, seal_pos.z + 2.4))
		game.player.rotation.y = 0.0
		game.player.camera.rotation.x = -0.14
		await _wait(0.4)
		await _shot("07b_seal")

	# записка
	game.hud.show_note("Страница из книги",
		"Три печати держат вход: соль, воск и имя.\n\n"
		+ "Пока хоть одна цела — дом не выпустит. Когда все три снимут с мест,\n"
		+ "дверь сама отойдёт в сторону, и никто не должен стоять на пороге.")
	await _wait(0.5)
	await _shot("08_note")
	game.hud.close_note()
	await _wait(0.3)

	# Хозяйка перед игроком
	game.ghost.awaken()
	var forward: Vector3 = -game.player.camera.global_transform.basis.z
	game.ghost.global_position = game.player.global_position + forward * 2.8 + Vector3(0, 0.15, 0)
	game.ghost.start_hunt_now()
	game.ghost._alpha = 0.92
	await _wait(0.25)
	await _shot("09_ghost")

	# пауза
	game.hud.show_pause()
	await _wait(0.4)
	await _shot("10_pause")
	game.hud.hide_pause()
	await _wait(0.2)

	# снимаем все печати и смотрим на открытый выход
	game.ghost.active = false
	game.ghost.visible = false
	for n in get_tree().get_nodes_in_group("house_interactable"):
		if n.kind == "seal":
			game._take_seal(n)
	await _wait(2.0)
	_look(Vector2(0.0, 4.6), 180.0)
	await _wait(0.4)
	await _shot("11_exit_open")

	# смерть
	game.hud.show_death()
	await _wait(0.4)
	await _shot("12_death")
	game.hud.clear_modals()
	await _wait(0.2)

	# победа
	game.hud.show_win(
		"Ты выходишь на крыльцо. Дождь.\n\n"
		+ "За спиной дом закрывает дверь сам — тихо, без скрипа.\n"
		+ "Смена, которую ты искала, осталась внутри. Но теперь ты знаешь её имена.\n\n"
		+ "Прочитано записей: 5 из 5. Печатей снято: 3.")
	await _wait(0.4)
	await _shot("13_win")

	print("CAPTURE3D DONE")
	await _wait(0.3)
	get_tree().quit()


func _look(cell: Vector2, yaw_deg: float) -> void:
	var pos: Vector3 = game._snap(cell)
	game.player.teleport_to(Vector3(pos.x, pos.y + 0.92, pos.z))
	game.player.rotation.y = deg_to_rad(yaw_deg)
	game.player.camera.rotation.x = -0.06


func _find_first(kind: String) -> Vector3:
	for n in get_tree().get_nodes_in_group("house_interactable"):
		if n.kind == kind:
			return n.global_position
	return Vector3.ZERO


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png("%s/%s.png" % [_dir, name])
	print("CAPTURE3D %s err=%d fps=%d intro=%.2f paused=%s scale=%.2f tween=%s t=%d" % [
		name, err, Engine.get_frames_per_second(), game.hud._intro.modulate.a,
		str(get_tree().paused), Engine.time_scale,
		str(game.hud._intro_tween.is_running() if game.hud._intro_tween != null else false),
		Time.get_ticks_msec()])
