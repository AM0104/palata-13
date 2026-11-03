extends Node
## Автотест выбора ответа в диалогах: настоящий клик мышью по кнопке,
## подтверждение клавишей Enter и навигация стрелками.
## Запуск: godot --path . -- --choice-test

var main: Node
var fails := 0
var checks := 0


func _ready() -> void:
	main = get_parent()
	var guard := get_tree().create_timer(60.0, true, false, true)
	guard.timeout.connect(func() -> void:
		print("CHOICETEST: ТАЙМАУТ (проверок %d, ошибок %d)" % [checks, fails])
		get_tree().quit())
	await _wait(0.6)
	await _run()
	print("CHOICETEST: проверок %d, ошибок %d" % [checks, fails])
	get_tree().quit()


func _run() -> void:
	main._on_new_game()
	await _wait(0.6)
	main.ui.close_modals()
	await _wait(0.2)

	# ---------- A. клик мышью по первому варианту ----------
	await _open()
	var buttons := _buttons()
	_ok(buttons.size() == 2, "A: показано два варианта ответа (%d)" % buttons.size())
	if buttons.size() > 0:
		var center: Vector2 = buttons[0].get_global_rect().get_center()
		_ok(center.y > 0.0 and center.y < 720.0, "A: первый вариант внутри экрана (y=%.0f)" % center.y)
		await _click(center)
	_ok(Game.flag("b5_met_grisha"), "A: клик мышью выбрал первый ответ")
	_ok(_buttons().is_empty(), "A: после выбора список вариантов убран")

	# ---------- B. клик мышью по второму варианту (ветка goto) ----------
	await _open()
	buttons = _buttons()
	if buttons.size() > 1:
		await _click(buttons[1].get_global_rect().get_center())
	_ok(Game.flag("b5_met_grisha"), "B: клик мышью выбрал второй ответ")
	_ok(_buttons().is_empty() and main.ui.dialog.visible, "B: ветка goto показала реплику без вариантов")

	# ---------- C. клик вне кнопок ничего не делает ----------
	await _open()
	await _click(Vector2(60, 60))
	_ok(main.ui.dialog.visible, "C: клик вне кнопок не закрывает диалог")
	_ok(not Game.flag("b5_met_grisha"), "C: клик вне кнопок не выбирает ответ")
	_ok(_buttons().size() == 2, "C: варианты остались на месте (%d)" % _buttons().size())

	# ---------- D. стрелка вниз + Enter ----------
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	await _wait(0.2)
	_ok(Game.flag("b5_met_grisha"), "D: Enter подтвердил выбранный стрелкой ответ")
	_ok(_buttons().is_empty() and main.ui.dialog.visible, "D: переход по goto показал реплику без вариантов")

	# ---------- E. Enter без стрелок подтверждает первый вариант ----------
	await _open()
	await _key(KEY_ENTER)
	await _wait(0.2)
	_ok(Game.flag("b5_met_grisha"), "E: Enter подтвердил первый вариант по умолчанию")
	_ok(main.ui.dialog.visible, "E: после ответа диалог продолжается репликой")

	# ---------- F. реплики листаются кликом ----------
	var steps := 0
	while main.ui.dialog.visible and steps < 12:
		steps += 1
		await _click(Vector2(640, 300))
		await _wait(0.2)
	_ok(not main.ui.dialog.visible, "F: реплики листаются кликом, диалог закрылся за %d кликов" % steps)

	main.ui.close_modals()


# --- вспомогательное -------------------------------------------------------

func _open() -> void:
	main.ui.close_modals()
	await _wait(0.2)
	Game.flags.erase("b5_met_grisha")
	main.ui.show_dialog("grisha_first")
	for _i in 40:
		await _wait(0.05)
		if _buttons().size() > 0:
			break
		if main.ui.dialog.visible:
			main.ui.dialog._advance()
	await _wait(0.1)


func _buttons() -> Array:
	var out: Array = []
	for c in main.ui.dialog.choice_box.get_children():
		if c is Button:
			out.append(c)
	return out


func _click(pos: Vector2) -> void:
	_mouse(pos, true)
	await _wait(0.06)
	_mouse(pos, false)
	await _wait(0.06)


func _mouse(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	ev.position = pos
	ev.global_position = pos
	get_viewport().push_input(ev)


func _key(code: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = code
	down.keycode = code
	down.pressed = true
	get_viewport().push_input(down)
	await _wait(0.06)
	var up := InputEventKey.new()
	up.physical_keycode = code
	up.keycode = code
	up.pressed = false
	get_viewport().push_input(up)
	await _wait(0.06)


func _ok(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		fails += 1
	print("%s %s" % ["[OK]  " if condition else "[FAIL]", message])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

