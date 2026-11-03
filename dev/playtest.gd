extends Node
## Автотест игровой логики: проходит все четыре горизонта «руками» и проверяет флаги.
## Запуск: godot --path . -- --playtest

var main: Node
var fails := 0
var checks := 0
var _save_backup := ""
var _save_existed := false


func _ready() -> void:
	main = get_parent()
	var guard := get_tree().create_timer(120.0, true, false, true)
	guard.timeout.connect(func() -> void:
		print("PLAYTEST: ТАЙМАУТ — тест не завершился за 120 с (проверок %d, ошибок %d)" % [checks, fails])
		get_tree().quit())
	await _wait(0.6)
	_backup_save()
	await _run()
	_restore_save()
	print("PLAYTEST: проверок %d, ошибок %d" % [checks, fails])
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
	main._on_new_game()
	await _wait(0.5)
	main.ui.close_modals()
	Game.hp = Game.max_hp
	await _wait(0.4)

	# ================= B5 =================
	await _check_floor(0, "B5")

	# --- запертая дверь не пускает без ключа, ключ её открывает
	var d_morgue := _door("Дверь насосной")
	if d_morgue != null:
		d_morgue.interact(main.world.player)
		await _wait(0.2)
		_ok(not d_morgue.is_open(), "Г5: дверь насосной заперта без ключа")
		_ok(d_morgue.is_blocking(), "B5: запертый створ физически перекрывает проход")
		main.ui.close_modals()
	var key_m := _one("pickup", "key_morgue")
	if key_m != null:
		key_m.interact(main.world.player)
		await _wait(0.05)
	_ok(Game.has_item("key_morgue"), "Г5: ключ насосной найден в палатах")
	if d_morgue != null and is_instance_valid(d_morgue):
		d_morgue.interact(main.world.player)
		await _wait(0.2)
		_ok(d_morgue.is_open(), "Г5: ключ открыл дверь насосной")
		_ok(not d_morgue.is_blocking(), "B5: открытая дверь больше не перекрывает проход")

	# --- смерть: возврат к точке сохранения, без лечения
	var save_pt := _one("save")
	if save_pt != null:
		main.world.player.teleport(save_pt.global_position)
		await _wait(0.2)
		save_pt.interact(main.world.player)
		await _wait(0.2)
		Game.hp = 2
		main.world.player.teleport(save_pt.global_position + Vector2(200, 0))
		Game._is_dead = true
		main._on_retry()
		await _wait(0.2)
		_ok(Game.hp == 1, "Смерть: возрождение с одним сердцем (%d)" % Game.hp)
		_ok(main.world.player.global_position.distance_to(save_pt.global_position) < 40.0,
			"Смерть: возврат к точке сохранения")
		Game.hp = Game.max_hp

	# --- проверка ввода: движение и взаимодействие
	var x0: float = main.world.player.global_position.x
	Input.action_press("move_right")
	await _wait(0.7)
	Input.action_release("move_right")
	await _wait(0.15)
	_ok(main.world.player.global_position.x > x0 + 12.0,
		"Ввод: Вера двигается по клавише (+%.1f px)" % (main.world.player.global_position.x - x0))

	var first_note := _one("note")
	if first_note != null:
		main.world.player.teleport(first_note.global_position + Vector2(0, 30))
		await _wait(0.4)
		_ok(main.world.player.current_target() == first_note, "Ввод: записка попала в радиус действия")
		var ev := InputEventAction.new()
		ev.action = "interact"
		ev.pressed = true
		Input.parse_input_event(ev)
		await _wait(0.3)
		_ok(main.ui.panel.visible, "Ввод: клавиша E открывает записку")
		main.ui.panel.close_panel()
		await _wait(0.15)

	var notes := _all("note")
	_ok(notes.size() >= 4, "B5: записки на этаже (найдено %d)" % notes.size())

	# --- панель молчит, пока игрок не добыл знание
	var keypad := _one("keypad")
	if keypad != null:
		keypad.interact(main.world.player)
		await _wait(0.2)
		_ok(main.ui.dialog.visible and not main.ui.panel.visible,
			"B5: без знаний панель сейфа не открывается")
		await _run_dialog(0)
		main.ui.close_modals()

	for n in notes:
		n.interact(main.world.player)
		await _wait(0.05)
	main.ui.close_modals()
	_ok(Game.notes.size() >= 4, "B5: записи попали в журнал (%d)" % Game.notes.size())

	var lore := _one("lore")
	if lore != null:
		lore.interact(main.world.player)
		await _wait(0.05)
		main.ui.close_modals()
	_ok(Game.flag("b5_code"), "B5: первая плита дала срок после первого пациента")
	_ok(Game.flag("b5_year"), "B5: приказ об открытии дал точку отсчёта")

	if keypad != null:
		main.world.player._invuln = 0.0
		_ok(not keypad.submit_code("0000"), "B5: неверный код отвергнут")
		_ok(main.world.player._invuln > 0.0, "B5: ошибка в коде наказывается уроном")
		_ok(keypad.submit_code("1934"), "B5: вычисленный код (1900 + 34) принят")
	_ok(Game.has_item("keycard"), "B5: получена ключ-карта")
	var med := _one("pickup", "medkit")
	if med != null:
		med.interact(main.world.player)
		await _wait(0.05)
	_ok(Game.has_item("medkit"), "B5: аптечка подобрана")

	var exit := _one("exit")
	if exit != null:
		exit.interact(main.world.player)
		await _wait(0.2)
		await _run_dialog(0)
	_ok(Game.flag("b5_done"), "B5: диалог у лифта выставил b5_done")
	if exit != null and is_instance_valid(exit):
		exit.interact(main.world.player)
	await _wait(1.2)
	_ok(main.world.floor_index == 1, "B5 → B4 переход (этаж %d)" % main.world.floor_index)
	main.ui.close_modals()
	await _wait(0.3)

	# ================= B4 =================
	Game.hp = Game.max_hp
	var d_gate := _door("Калитка")
	if d_gate != null:
		d_gate.interact(main.world.player)
		await _wait(0.2)
		_ok(not d_gate.is_open(), "B4: калитка заперта без пропуска")
		main.ui.close_modals()

	var shovel := _one("pickup", "shovel")
	if shovel != null:
		shovel.interact(main.world.player)
		await _wait(0.05)
	_ok(Game.has_item("shovel"), "B4: лопата найдена в сарае")

	var pass_item := _one("pickup", "grave_pass")
	if pass_item != null:
		pass_item.interact(main.world.player)
		await _wait(0.05)
	_ok(Game.has_item("grave_pass"), "Г4: пропуск маркшейдера найден в сарае")
	if d_gate != null and is_instance_valid(d_gate):
		d_gate.interact(main.world.player)
		await _wait(0.2)
		_ok(d_gate.is_open(), "B4: пропуск открыл калитку")

	var graves := _kind_sorted("grave")
	_ok(graves.size() >= 3, "B4: три камня со знаками (найдено %d)" % graves.size())
	if graves.size() >= 3:
		# первый камень — верно
		graves[0].interact(main.world.player)
		await _wait(0.15)
		await _run_dialog(0)
		main.ui.close_modals()
		_ok(Game.counter("b4_dig") == 1, "B4: первый камень вскрыт (%d)" % Game.counter("b4_dig"))

		# ошибка: земля смыкается, порядок заново, удар
		main.world.player._invuln = 0.0
		graves[2].interact(main.world.player)
		await _wait(0.15)
		_ok(main.ui.dialog.visible, "Г4: неверный порядок вызывает разговор Тихона")
		await _run_dialog(0)
		main.ui.close_modals()
		_ok(Game.counter("b4_dig") == 0, "B4: ошибка сбросила порядок (%d)" % Game.counter("b4_dig"))
		_ok(main.world.player._invuln > 0.0, "Г4: ошибка ранит Веру")
		_ok(not Game.flag("dug:%s" % graves[0]._fid()), "B4: вскрытый камень снова закрыт")

		# верный порядок
		for g in graves:
			g.interact(main.world.player)
			await _wait(0.1)
			await _run_dialog(0)
			main.ui.close_modals()
		_ok(Game.counter("b4_dig") == 3, "B4: три камня вскрыты в порядке (%d)" % Game.counter("b4_dig"))
		_ok(Game.has_item("key_crypt"), "B4: второй камень отдал ключ склепа")
		var d_crypt := _door("Дверь склепа")
		if d_crypt != null:
			d_crypt.interact(main.world.player)
			await _wait(0.2)
			_ok(d_crypt.is_open(), "B4: ключ из земли открыл склеп")
		_ok(Game.has_item("grave_key"), "Г4: получен ключ подъёмника")
		exit = _one("exit")
		if exit != null:
			exit.interact(main.world.player)
			await _wait(0.3)
			await _run_dialog(0)
	await _wait(1.2)
	_ok(main.world.floor_index == 2, "B4 → B3 переход (этаж %d)" % main.world.floor_index)
	main.ui.close_modals()
	await _wait(0.3)

	# ================= B3 =================
	Game.hp = Game.max_hp
	var d_block := _door("Ворота блока Б")
	if d_block != null:
		d_block.interact(main.world.player)
		await _wait(0.2)
		_ok(not d_block.is_open(), "Г3: блок Б заперт без ключа табельщицы")
		main.ui.close_modals()

	var block_key := _one("pickup", "key_block")
	if block_key != null:
		block_key.interact(main.world.player)
		await _wait(0.05)
	_ok(Game.has_item("key_block"), "Г3: ключ блока найден в комнате охраны")
	if d_block != null and is_instance_valid(d_block):
		d_block.interact(main.world.player)
		await _wait(0.2)
		_ok(d_block.is_open(), "B3: ключ открыл блок Б")

	var keys := _one("pickup", "key_cell")
	if keys != null:
		keys.interact(main.world.player)
		await _wait(0.05)
	_ok(Game.has_item("key_cell"), "B3: связка ключей найдена")

	var prisoner := _find_npc("survivor")
	if prisoner != null:
		prisoner.interact(main.world.player)
		await _wait(0.2)
		await _run_dialog(0)
		main.ui.close_modals()
	_ok(Game.flag("b3_prisoner_freed"), "Г3: выживший освобождён")
	_ok(Game.has_item("file"), "B3: получено дело заключённого")

	# --- без рапорта комиссия не начинается
	var zoya := _find_npc("zoya")
	if zoya != null:
		zoya.interact(main.world.player)
		await _wait(0.2)
		_ok(not Game.flag("b3_done"), "Г3: без рапорта табельщицы комиссия не начинается")
		await _run_dialog(0)
		main.ui.close_modals()

	for n in _all("note"):
		n.interact(main.world.player)
		await _wait(0.05)
	main.ui.close_modals()
	_ok(Game.flag("b3_evidence"), "Г3: рапорт табельщицы дал улику")

	# --- суд: сначала ложь (наказание), потом правда
	if zoya != null:
		zoya.interact(main.world.player)
		await _wait(0.2)
		main.world.player._invuln = 0.0
		await _answer(0)          # «Трое» — ложь
		await _until_choices()    # домотать до повторного вопроса
		_ok(main.world.player._invuln > 0.0, "Г3: ложь комиссии наказывается уроном")
		await _answer(1)          # четверо — верно
		await _answer(1)          # кого предала
		await _answer(1)          # что сделаешь с Климом
		await _run_dialog(0)
		main.ui.close_modals()
	_ok(Game.flag("b3_done"), "Г3: комиссия Зои пройдена")
	exit = _one("exit")
	if exit != null:
		exit.interact(main.world.player)
	await _wait(1.2)
	_ok(main.world.floor_index == 3, "B3 → B2 переход (этаж %d)" % main.world.floor_index)
	main.ui.close_modals()
	await _wait(0.3)

	# ================= B2 =================
	Game.hp = Game.max_hp

	# --- ризница открывается ключом Грея
	var d_vestry := _door("Дверь левой кладовой")
	if d_vestry != null:
		d_vestry.interact(main.world.player)
		await _wait(0.2)
		_ok(not d_vestry.is_open(), "Г2: кладовая заперта без ключа")
		main.ui.close_modals()
	var gray := _find_npc("dispatcher")
	if gray != null:
		gray.interact(main.world.player)
		await _wait(0.2)
		await _run_dialog(1)
		main.ui.close_modals()
	_ok(Game.has_item("key_vestry"), "Г2: Диспетчер дал ключ кладовой")
	if d_vestry != null and is_instance_valid(d_vestry):
		d_vestry.interact(main.world.player)
		await _wait(0.2)
		_ok(d_vestry.is_open(), "Г2: ключ открыл кладовую")

	var candles := _kind_sorted("candle")
	_ok(candles.size() == 4, "Г2: четыре лампы (найдено %d)" % candles.size())
	if candles.size() == 4:
		main.world.player._invuln = 0.0
		candles[2].interact(main.world.player)
		await _wait(0.2)
		_ok(main.ui.dialog.visible, "Г2: лампа не в свою очередь вызывает ответ Диспетчера")
		await _run_dialog(0)
		main.ui.close_modals()
		_ok(Game.counter("b2_candles") == 0, "Г2: счётчик ламп сброшен (0)")
		_ok(main.world.player._invuln > 0.0, "Г2: неверная лампа ранит")
		for c in candles:
			c.interact(main.world.player)
			await _wait(0.1)
		_ok(Game.flag("b2_candles_lit"), "Г2: четыре лампы горят")
		_ok(Game.flag("b2_third_lit"), "Г2: третья лампа подняла решётку пульта")
		var d_rail := _door("Решётка")
		if d_rail != null:
			d_rail.interact(main.world.player)
			await _wait(0.2)
			_ok(d_rail.is_open(), "Г2: решётка пульта открыта")

	# --- алтарь без распятия молчит
	Game.hp = Game.max_hp
	var altar := _one("altar")
	if altar != null:
		altar.interact(main.world.player)
		await _wait(0.3)
		await _run_dialog(0)
		main.ui.close_modals()
	_ok(not main.ui.end_ui.visible, "Г2: без жетона пульт не открывает финал")

	var cross := _one("pickup", "cross")
	if cross != null:
		cross.interact(main.world.player)
		await _wait(0.05)
	_ok(Game.has_item("cross"), "Г2: шахтёрский жетон найден в нефе")

	if altar != null:
		altar.interact(main.world.player)
		await _wait(0.3)
		await _run_dialog(0)
	await _wait(0.4)
	_ok(main.ui.end_ui.visible, "Г2: пульт приводит к финалу")
	_ok(Game.ending != "", "Г2: финал зафиксирован (%s)" % Game.ending)
	main.ui.close_modals()

	# ================= сохранение =================
	Game.floor_index = 2
	_ok(Game.save_game(), "Сохранение: запись выполнена")
	var hp_before := Game.hp
	Game.hp = 1
	Game.inventory.clear()
	_ok(Game.load_game(), "Сохранение: загрузка выполнена")
	_ok(Game.hp == hp_before, "Сохранение: здоровье восстановлено (%d)" % Game.hp)
	_ok(Game.floor_index == 2, "Сохранение: этаж восстановлен (%d)" % Game.floor_index)
	_ok(Game.has_item("keycard"), "Сохранение: инвентарь восстановлен")
	_ok(Game.notes.size() >= 3, "Сохранение: журнал восстановлен (%d)" % Game.notes.size())


# --- вспомогательное -------------------------------------------------------

func _check_floor(index: int, label: String) -> void:
	_ok(main.world.floor_index == index, "%s: этаж загружен" % label)
	_ok(main.world.player != null, "%s: игрок создан" % label)
	_ok(main.world.companion != null, "%s: Клим создан" % label)


func _all(kind: String) -> Array:
	var out: Array = []
	for it in get_tree().get_nodes_in_group("interactables"):
		if it is Interactable and it.kind == kind and it.available:
			out.append(it)
	return out


func _one(kind: String, item: String = "") -> Interactable:
	for it in _all(kind):
		if item == "" or str(it.data.get("item", "")) == item:
			return it
	return null


func _kind_sorted(kind: String) -> Array:
	var arr := _all(kind)
	arr.sort_custom(func(a, b): return int(a.data.get("order", 0)) < int(b.data.get("order", 0)))
	return arr


func _find_npc(who: String) -> Interactable:
	for it in _all("npc"):
		if str(it.data.get("who", "")) == who:
			return it
	return null


func _door(label_prefix: String) -> Interactable:
	for it in _all("door"):
		if str(it.data.get("label", "")).begins_with(label_prefix):
			return it
	return null


func _run_dialog(choice_index: int, max_steps: int = 200) -> void:
	var steps := 0
	while main.ui.dialog.visible and steps < max_steps:
		steps += 1
		var buttons := _choice_buttons()
		if buttons.size() > 0:
			var idx: int = clampi(choice_index, 0, buttons.size() - 1)
			buttons[idx].pressed.emit()
		else:
			main.ui.dialog._advance()
		await _wait(0.03)
	if steps >= max_steps:
		_ok(false, "Диалог не завершился за %d шагов" % max_steps)


func _choice_buttons() -> Array:
	var out: Array = []
	for c in main.ui.dialog.choice_box.get_children():
		if c is Button:
			out.append(c)
	return out


## Домотать диалог до очередных вариантов ответа.
func _until_choices(max_steps: int = 80) -> void:
	var steps := 0
	while main.ui.dialog.visible and _choice_buttons().is_empty() and steps < max_steps:
		steps += 1
		main.ui.dialog._advance()
		await _wait(0.03)


## Ответить на вопрос суда: домотать до вариантов и нажать нужный.
func _answer(choice_index: int) -> void:
	await _until_choices()
	var buttons := _choice_buttons()
	if buttons.is_empty():
		return
	buttons[clampi(choice_index, 0, buttons.size() - 1)].pressed.emit()
	await _wait(0.05)


func _ok(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		fails += 1
	print("%s %s" % ["[OK]  " if condition else "[FAIL]", message])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


