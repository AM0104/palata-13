extends Node
## Автотест настроек экрана: полноэкранный режим из меню, клавиша F11 и файл user://settings.cfg.
## Запуск (нужно настоящее окно, без --headless): godot --path . -- --window-test

var main: Node
var checks := 0
var fails := 0
var _start_mode := 0
var _start_fullscreen := false


func _ready() -> void:
	main = get_parent()
	# состояние окна до любых правок: так проверяем применение сохранённой настройки при старте
	_start_mode = DisplayServer.window_get_mode()
	_start_fullscreen = Settings.fullscreen
	get_tree().create_timer(60.0, true, false, true).timeout.connect(func() -> void:
		print("WINDOW-TEST: ТАЙМАУТ")
		get_tree().quit())
	await _wait(0.8)
	await _run()
	print("WINDOW-TEST: проверок %d, ошибок %d" % [checks, fails])
	get_tree().quit()


func _run() -> void:
	_ok(Settings != null, "Автолоад Settings загружен")
	_ok(InputMap.has_action("fullscreen"), "Действие F11 зарегистрировано")

	# --- файл настроек
	Settings.set_volume(0.35)
	Settings.set_fullscreen(false)
	Settings.save_settings()
	_ok(FileAccess.file_exists(Settings.config_path()),
		"Настройки записаны в %s" % Settings.config_path())

	if Settings.window_available():
		_ok((_start_mode == DisplayServer.WINDOW_MODE_FULLSCREEN) == _start_fullscreen,
			"Старт: сохранённый режим применён (файл fullscreen=%s, окно режим %d)"
				% [str(_start_fullscreen), _start_mode])

	# --- настройки переживают перезапуск
	Settings.volume = 1.0
	Settings.fullscreen = false
	Settings.load_settings()
	_ok(is_equal_approx(Settings.volume, 0.35), "Громкость прочитана из файла (%.2f)" % Settings.volume)

	# --- переключатель в настройках меню
	main.ui.show_main_menu()
	await _wait(0.2)
	main.ui.menu._show_settings(false)
	await _wait(0.2)
	var fs := _checkbox()
	_ok(fs != null, "В настройках есть переключатель «ПОЛНЫЙ ЭКРАН»")
	if fs == null:
		return

	if not Settings.window_available():
		print("WINDOW-TEST: окно недоступно (%s) — проверяю только файл настроек" % DisplayServer.get_name())
		Settings.set_volume(0.8)
		Settings.save_settings()
		return

	_ok(not fs.button_pressed, "Флажок выключен, пока окно оконное")

	fs.button_pressed = true
	await _wait(0.5)
	_ok(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,
		"Клик по флажку включил полный экран (режим %d)" % DisplayServer.window_get_mode())
	_ok(Settings.fullscreen, "Настройка запомнила полный экран")

	fs.button_pressed = false
	await _wait(0.5)
	_ok(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED,
		"Повторный клик вернул оконный режим (режим %d)" % DisplayServer.window_get_mode())

	# --- F11 переключает режим и синхронизирует флажок
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F11
	ev.pressed = true
	Input.parse_input_event(ev)
	await _wait(0.6)
	_ok(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,
		"F11 включил полный экран (режим %d)" % DisplayServer.window_get_mode())
	_ok(fs.button_pressed, "Флажок синхронизировался с F11")

	# --- сохранённый полный экран применяется при старте
	Settings.set_fullscreen(true)
	Settings.save_settings()
	Settings.fullscreen = false
	Settings.load_settings()
	_ok(Settings.fullscreen, "Полный экран прочитан из файла")

	# --- возвращаем оконный режим, чтобы не удивлять игрока
	Settings.set_fullscreen(false)
	Settings.set_volume(0.8)
	Settings.save_settings()
	await _wait(0.4)
	_ok(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED,
		"Оконный режим восстановлен (режим %d)" % DisplayServer.window_get_mode())


func _checkbox() -> CheckButton:
	for c in main.ui.menu._settings_box.get_children():
		if c is CheckButton:
			return c
	return null


func _ok(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		fails += 1
	print("%s %s" % ["[OK]  " if condition else "[FAIL]", message])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout