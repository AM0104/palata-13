class_name MenuUi
extends Control
## Главное меню, пауза и настройки.

signal new_game_requested
signal continue_requested
signal quit_requested
signal resume_requested
signal save_requested
signal to_menu_requested

var _bg: TextureRect
var _main_box: VBoxContainer
var _pause_box: VBoxContainer
var _settings_box: VBoxContainer
var _title: Label
var _subtitle: Label
var _save_info: Label
var _status: Label
var _difficulty_label: Label
var _record_label: Label
var _from_pause := false


func _ready() -> void:
	UiTheme.fullscreen(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _build() -> void:
	_bg = TextureRect.new()
	UiTheme.fullscreen(_bg)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.texture = Art.background("menu")
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	var grad := ColorRect.new()
	UiTheme.fullscreen(grad)
	grad.color = Color(0.02, 0.02, 0.03, 0.55)
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grad)

	var strip := ColorRect.new()
	UiTheme.fullscreen(strip)
	strip.color = Color(0, 0, 0, 0.0)
	add_child(strip)

	_title = UiTheme.make_label("ПАЛАТА 13", 62, Color(0.93, 0.90, 0.86))
	_title.position = Vector2(70, 62)
	add_child(_title)

	_subtitle = UiTheme.make_label("ТИХИЙ КЛИНИЧЕСКИЙ ХОРРОР · КОРПУС Б · МИША", 16, UiTheme.DIM)
	_subtitle.position = Vector2(74, 158)
	add_child(_subtitle)

	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.18)
	line.position = Vector2(74, 194)
	line.size = Vector2(460, 2)
	add_child(line)

	# --- главное меню
	_main_box = VBoxContainer.new()
	_main_box.position = Vector2(74, 232)
	_main_box.add_theme_constant_override("separation", 6)
	add_child(_main_box)
	var b_new := UiTheme.make_button("НОВАЯ ИГРА", 24)
	b_new.pressed.connect(func() -> void: new_game_requested.emit())
	_main_box.add_child(b_new)
	var b_cont := UiTheme.make_button("ПРОДОЛЖИТЬ", 24)
	b_cont.pressed.connect(func() -> void: continue_requested.emit())
	_main_box.add_child(b_cont)
	var b_set := UiTheme.make_button("НАСТРОЙКИ", 24)
	b_set.pressed.connect(_show_settings.bind(false))
	_main_box.add_child(b_set)
	var b_quit := UiTheme.make_button("ВЫХОД", 24)
	b_quit.pressed.connect(func() -> void: quit_requested.emit())
	_main_box.add_child(b_quit)

	_save_info = UiTheme.make_label("", 15, UiTheme.DIM)
	_save_info.position = Vector2(74, 620)
	add_child(_save_info)

	_difficulty_label = UiTheme.make_label("", 15, UiTheme.GOLD)
	_difficulty_label.position = Vector2(74, 642)
	add_child(_difficulty_label)

	_record_label = UiTheme.make_label("", 14, UiTheme.DIM)
	_record_label.position = Vector2(74, 666)
	add_child(_record_label)

	# --- пауза
	_pause_box = VBoxContainer.new()
	_pause_box.position = Vector2(74, 224)
	_pause_box.add_theme_constant_override("separation", 6)
	_pause_box.visible = false
	add_child(_pause_box)
	var p_res := UiTheme.make_button("ПРОДОЛЖИТЬ", 24)
	p_res.pressed.connect(func() -> void: resume_requested.emit())
	_pause_box.add_child(p_res)
	var p_save := UiTheme.make_button("СОХРАНИТЬ", 24)
	p_save.pressed.connect(func() -> void: save_requested.emit())
	_pause_box.add_child(p_save)
	var p_set := UiTheme.make_button("НАСТРОЙКИ", 24)
	p_set.pressed.connect(_show_settings.bind(true))
	_pause_box.add_child(p_set)
	var p_menu := UiTheme.make_button("В ГЛАВНОЕ МЕНЮ", 24)
	p_menu.pressed.connect(func() -> void: to_menu_requested.emit())
	_pause_box.add_child(p_menu)

	# --- настройки
	_settings_box = VBoxContainer.new()
	_settings_box.position = Vector2(74, 224)
	_settings_box.add_theme_constant_override("separation", 10)
	_settings_box.visible = false
	add_child(_settings_box)
	_settings_box.add_child(UiTheme.make_label("ГРОМКОСТЬ", 18, UiTheme.GOLD))
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = Settings.volume
	vol.custom_minimum_size = Vector2(300, 24)
	vol.value_changed.connect(func(v: float) -> void: Settings.set_volume(v))
	_settings_box.add_child(vol)
	var fs := CheckButton.new()
	fs.text = "ПОЛНЫЙ ЭКРАН"
	fs.add_theme_font_size_override("font_size", 18)
	fs.add_theme_color_override("font_color", UiTheme.TEXT)
	fs.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	# иначе переключатель растягивается на всю колонку и флажок уезжает от подписи
	fs.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	fs.button_pressed = Settings.is_fullscreen()
	fs.toggled.connect(func(on: bool) -> void: Settings.set_fullscreen(on))
	# F11 меняет режим минуя настройки — держим флажок синхронным
	Settings.fullscreen_changed.connect(func(on: bool) -> void: fs.set_pressed_no_signal(on))
	_settings_box.add_child(fs)
	var hint := UiTheme.make_label(Settings.window_hint(), 13, UiTheme.DIM)
	hint.custom_minimum_size = Vector2(620, 0)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_settings_box.add_child(hint)
	var del := UiTheme.make_button("УДАЛИТЬ СОХРАНЕНИЕ", 18)
	del.pressed.connect(func() -> void:
		Game.delete_save()
		_status.text = "Сохранение удалено."
		_refresh_save_info())
	_settings_box.add_child(del)
	var back := UiTheme.make_button("НАЗАД", 20)
	back.pressed.connect(func() -> void: _close_settings())
	_settings_box.add_child(back)

	_status = UiTheme.make_label("", 15, UiTheme.ACCENT)
	_status.position = Vector2(74, 692)
	add_child(_status)


func show_main() -> void:
	visible = true
	_from_pause = false
	_main_box.visible = true
	_pause_box.visible = false
	_settings_box.visible = false
	_title.text = "ПАЛАТА 13"
	_subtitle.text = "ТИХИЙ КЛИНИЧЕСКИЙ ХОРРОР · КОРПУС Б · МИША"
	_bg.texture = Art.background("menu")
	_bg.modulate = Color(1, 1, 1, 1)
	_status.text = ""
	_refresh_save_info()
	_refresh_difficulty()
	_focus_first(_main_box)


func show_pause() -> void:
	visible = true
	_from_pause = true
	_main_box.visible = false
	_settings_box.visible = false
	_pause_box.visible = true
	_title.text = "ПАУЗА"
	_subtitle.text = "Тишина. Даже вентиляция замерла."
	_bg.texture = Art.background("menu")
	_bg.modulate = Color(0.75, 0.75, 0.8, 1)
	_status.text = "%s · %s · %s · призраков: %d · %s" % [
		Levels.floor_name(Game.floor_index), Game.difficulty_name(),
		Game.format_time(), Game.kills, Game.rank_line(),
	]
	_refresh_difficulty()
	_focus_first(_pause_box)


## Сложность не выбирается из меню: окно выбора открывается только по «Новой игре».
## Подпись лишь напоминает игроку текущий уровень.
func _refresh_difficulty() -> void:
	if _difficulty_label == null:
		return
	if Game.in_game():
		_difficulty_label.text = "Уровень партии: %s · %d сердец" % [Game.difficulty_name(), Game.max_hp]
	else:
		_difficulty_label.text = "Сложность: ГОСТЬ / ПАЦИЕНТ / ПАЛАТА 13 — выбор при старте новой игры."
	if _record_label != null:
		_record_label.text = Game.rank_line()


func _refresh_save_info() -> void:
	if Game.has_save():
		_save_info.text = "Сохранение найдено: %s" % Game.save_path()
	else:
		_save_info.text = "Сохранений нет."
	for c in _main_box.get_children():
		if c is Button and (c as Button).text == "ПРОДОЛЖИТЬ":
			(c as Button).disabled = not Game.has_save()


func _show_settings(from_pause: bool) -> void:
	_from_pause = from_pause
	_main_box.visible = false
	_pause_box.visible = false
	_settings_box.visible = true
	_title.text = "НАСТРОЙКИ"
	_subtitle.text = "Звук и окно."
	_focus_first(_settings_box)


func _close_settings() -> void:
	if _from_pause:
		show_pause()
	else:
		show_main()


func _focus_first(box: VBoxContainer) -> void:
	for c in box.get_children():
		if c is Button and not (c as Button).disabled:
			(c as Button).grab_focus()
			return


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("pause"):
		if _settings_box.visible:
			_close_settings()
		elif _pause_box.visible:
			resume_requested.emit()
		get_viewport().set_input_as_handled()



