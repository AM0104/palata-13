extends Node
## Автотест уровней сложности: лёгкая / средняя / сложная.
## Запуск: godot --path . -- --difficulty-test

var main: Node
var world: World
var checks := 0
var fails := 0
var _debug_players: Array = []
var _save_backup := ""
var _save_existed := false


func _ready() -> void:
	main = get_parent()
	get_tree().create_timer(90.0, true, false, true).timeout.connect(func() -> void:
		print("DIFFICULTY-TEST: ТАЙМАУТ")
		get_tree().quit())
	await _wait(0.6)
	_backup_save()
	await _run()
	_restore_save()
	print("DIFFICULTY-TEST: проверок %d, ошибок %d" % [checks, fails])
	get_tree().quit()


## Тест пишет настоящий save1.json: сохраняем файл игрока и возвращаем его на место.
func _backup_save() -> void:
	_save_existed = Game.has_save()
	if not _save_existed:
		return
	var f := FileAccess.open(Game.save_path(), FileAccess.READ)
	if f == null:
		return
	_save_backup = f.get_as_text()
	f.close()


func _restore_save() -> void:
	if not _save_existed:
		Game.delete_save()
		return
	var f := FileAccess.open(Game.save_path(), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(_save_backup)
	f.close()


func _run() -> void:
	_ok(Game.DIFFICULTY_NAMES.size() == 3, "Сложностей ровно три")
	_ok(Game.DIFFICULTY_NAMES == ["ШАХТЁР", "СМЕНА", "ГЛУБИНА"],
		"Названия уровней: %s" % str(Game.DIFFICULTY_NAMES))

	# --- лёгкая
	await _start(0, "ШАХТЁР")
	_ok(Game.max_hp == 8 and Game.hp == 8, "ШАХТЁР: 8 сердец (%d/%d)" % [Game.hp, Game.max_hp])
	_check_enemy("ШАХТЁР", 1.35, 0.85, 0.80, 1)   # хп 2 (0.65*2=1.3 -> 1), урон 1
	_ok(_companion_damage() == 5, "ШАХТЁР: лом Клима бьёт на %d" % _companion_damage())

	# --- средняя
	await _start(1, "СМЕНА")
	_ok(Game.max_hp == 6 and Game.hp == 6, "СМЕНА: 6 сердец (%d/%d)" % [Game.hp, Game.max_hp])
	_check_enemy("СМЕНА", 2.0, 1.0, 1.0, 1)
	_ok(_companion_damage() == 3, "СМЕНА: лом Клима бьёт на %d" % _companion_damage())

	# --- сложная
	await _start(2, "ГЛУБИНА")
	_ok(Game.max_hp == 4 and Game.hp == 4, "ГЛУБИНА: 4 сердца (%d/%d)" % [Game.hp, Game.max_hp])
	_check_enemy("ГЛУБИНА", 4.0, 1.15, 1.25, 2)
	_ok(_companion_damage() == 2, "ГЛУБИНА: лом Клима бьёт на %d" % _companion_damage())

	# --- переключение из меню по кругу
	Game.abandon_run()
	Game.set_difficulty(0)
	_ok(Game.difficulty_name() == "ШАХТЁР", "Меню: выбор лёгкой применяется (%s)" % Game.difficulty_name())
	Game.set_difficulty(2)
	_ok(Game.difficulty_name() == "ГЛУБИНА", "Меню: выбор сложной применяется (%s)" % Game.difficulty_name())
	_ok(Game.difficulty_desc() != "", "Меню: у уровня есть описание")
	_ok(not Game.in_game(), "Меню: после возврата сложность снова выбирается")

	# --- всплывающее окно выбора сложности
	main.ui.show_main_menu()
	await _wait(0.2)
	_ok(_press_menu("НОВАЯ ИГРА"), "Меню: кнопка «НОВАЯ ИГРА» на месте")
	await _wait(0.2)
	_ok(main.ui.difficulty_ui.visible, "Окно: всплыло при «Новой игре»")
	_ok(main.ui.difficulty_ui._buttons.size() == 3, "Окно: три варианта сложности")
	main.ui.difficulty_ui._pick(2)
	await _wait(0.6)
	_ok(not main.ui.difficulty_ui.visible, "Окно: закрылось после выбора")
	_ok(main.world != null and main.world.player != null, "Окно: выбор запустил партию")
	_ok(Game.difficulty == 2 and Game.max_hp == 4,
		"Окно: выбрана сложная (%s, %d сердец)" % [Game.difficulty_name(), Game.max_hp])

	# --- Esc в окне возвращает в главное меню
	main._on_to_menu()
	await _wait(0.2)
	main._request_new_game()
	await _wait(0.2)
	main.ui.difficulty_ui._cancel()
	await _wait(0.2)
	_ok(main.ui.menu.visible and not main.ui.difficulty_ui.visible,
		"Окно: Esc вернул в главное меню")

	# --- из меню сложность не меняется: выбор только по «Новой игре»
	main.ui.show_main_menu()
	await _wait(0.2)
	var diff_btn := ""
	for c in main.ui.menu._main_box.get_children():
		if c is Button and (c as Button).text.begins_with("СЛОЖНОСТЬ"):
			diff_btn = (c as Button).text
	_ok(diff_btn == "", "Меню: кнопки сложности нет (нашли '%s')" % diff_btn)
	_ok(Game.difficulty == 2 and not Game.in_game() and not main.ui.difficulty_ui.visible,
		"Меню: без «Новой игры» уровень не меняется (%s)" % Game.difficulty_name())

	# --- сложность сохраняется и восстанавливается
	Game.set_difficulty(2)
	await _start(-1, "ГЛУБИНА")
	_ok(Game.save_game(), "Сохранение: партия записана")
	Game.set_difficulty(0)
	_ok(Game.load_game(), "Сохранение: партия загружена")
	_ok(Game.difficulty == 2, "Сохранение: сложность восстановлена (%s)" % Game.difficulty_name())
	_ok(Game.max_hp == 4, "Сохранение: сердца под сложность (%d)" % Game.max_hp)

	# --- сложность меняется при старте новой партии
	await _start(0, "ШАХТЁР")
	main._on_new_game()
	await _wait(0.6)
	_ok(Game.max_hp == 8, "Новая партия: сложность взята из меню (%s, %d сердец)" % [Game.difficulty_name(), Game.max_hp])
	_ok(Game.in_game(), "Новая партия: сложность зафиксирована на время игры")


func _start(diff: int, expected: String) -> void:
	main._on_new_game()
	if diff >= 0:
		Game.set_difficulty(diff)
		Game.new_game(diff)
	await _wait(0.5)
	main.ui.close_modals()
	world = main.world
	_ok(world != null and world.player != null, "Этаж загружен для сложности '%s'" % expected)
	_ok(Game.difficulty_name() == expected, "Активна сложность %s (%s)" % [expected, Game.difficulty_name()])


func _check_enemy(tag: String, hp_expected: float, speed_mult: float, aggro_mult: float, damage: int) -> void:
	world = main.world
	if world == null or world.player == null:
		_ok(false, "%s: мир не создан" % tag)
		return
	var e := Enemy.new()
	var dummy := Player.new()
	dummy.input_enabled = false
	dummy.global_position = Vector2(-2000, -2000)
	world.ysort.add_child(dummy)
	_debug_players.append(dummy)
	e.setup("crawler", world.player.global_position + Vector2(300, 0), dummy)
	world.ysort.add_child(e)
	_ok(e.hp == int(round(hp_expected)), "%s: хп врага %d (ждали %d)" % [tag, e.hp, int(round(hp_expected))])
	_ok(is_equal_approx(e.speed, 54.0 * speed_mult), "%s: скорость врага %.1f" % [tag, e.speed])
	_ok(is_equal_approx(e.aggro_range, 210.0 * aggro_mult), "%s: дальность агра %.0f" % [tag, e.aggro_range])
	_ok(e.damage == damage, "%s: урон врага %d" % [tag, e.damage])
	e.queue_free()


func _companion_damage() -> int:
	return int(Game.difficulty_balance()["companion_damage"])


## Нажать кнопку главного меню по началу её подписи.
func _press_menu(prefix: String) -> bool:
	for c in main.ui.menu._main_box.get_children():
		if c is Button and (c as Button).text.begins_with(prefix) and not (c as Button).disabled:
			(c as Button).pressed.emit()
			return true
	return false


func _ok(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		fails += 1
	print("%s %s" % ["[OK]  " if condition else "[FAIL]", message])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

