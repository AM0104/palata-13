class_name DifficultyUi
extends Control
## Полноэкранный выбор сложности перед новой сменой.
## Карточки выбираются мышью или стрелками, Enter запускает, Esc отменяет.

signal chosen(index: int)
signal cancelled

var _bg: TextureRect
var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _sub: Label
var _summary: Label
var _start_btn: Button
var _cards: Array[PanelContainer] = []
var _buttons: Array[Button] = []
var _descs: Array[Label] = []
var _tags: Array[Label] = []
var _stats: Array[Label] = []
var _selected := 1
var _committed := false


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
	_bg.modulate = Color(0.55, 0.58, 0.58, 1)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_dim = ColorRect.new()
	UiTheme.fullscreen(_dim)
	_dim.color = Color(0.01, 0.02, 0.02, 0.78)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_panel = UiTheme.make_panel(UiTheme.BG, UiTheme.BORDER, 2)
	_panel.position = Vector2(100, 64)
	_panel.custom_minimum_size = Vector2(1080, 590)
	_panel.size = Vector2(1080, 590)
	add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)

	_title = UiTheme.make_label("ВЫБЕРИ НОЧЬ", 36, UiTheme.GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)

	_sub = UiTheme.make_label("Три способа войти в корпус Б. Разница не только в сердцах: меняются призраки, фонарь, воздух и цена ошибки.", 15, UiTheme.DIM)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_sub)

	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 16)
	col.add_child(cards)

	for i in Game.DIFFICULTY_NAMES.size():
		cards.add_child(_make_card(i))

	_summary = UiTheme.make_label("", 16, UiTheme.TEXT)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.custom_minimum_size = Vector2(900, 24)
	col.add_child(_summary)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	col.add_child(actions)

	_start_btn = UiTheme.make_button("НАЧАТЬ НОЧЬ", 22)
	_start_btn.custom_minimum_size = Vector2(300, 44)
	_start_btn.pressed.connect(_confirm)
	actions.add_child(_start_btn)

	var cancel := UiTheme.make_button("[Esc] НАЗАД", 18)
	cancel.custom_minimum_size = Vector2(180, 44)
	cancel.pressed.connect(_cancel)
	actions.add_child(cancel)


func _make_card(index: int) -> PanelContainer:
	var card := UiTheme.make_panel(UiTheme.BG_SOFT, UiTheme.BORDER, 2)
	card.custom_minimum_size = Vector2(315, 318)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	var tag := UiTheme.make_label(str(Game.DIFFICULTY_TAGS[index]), 12, UiTheme.DIM)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tag)

	var b := UiTheme.make_button(str(Game.DIFFICULTY_NAMES[index]), 26)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_select.bind(index))
	box.add_child(b)

	var stats := UiTheme.make_label("", 14, UiTheme.GOLD)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.custom_minimum_size = Vector2(280, 42)
	box.add_child(stats)

	var d := UiTheme.make_label(str(Game.DIFFICULTY_DESC[index]), 14, UiTheme.DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(280, 120)
	box.add_child(d)

	_cards.append(card)
	_buttons.append(b)
	_descs.append(d)
	_tags.append(tag)
	_stats.append(stats)
	return card


func _stat_text(index: int) -> String:
	match index:
		0:
			return "♥ 8 СЕРДЕЦ\nВРАГИ: СЛАБЫЕ · УРОН 1\nСВЕТ/ВОЗДУХ: −20%"
		2:
			return "♥ 4 СЕРДЦА\nВРАГИ: СИЛЬНЫЕ · УРОН 2\nСВЕТ/ВОЗДУХ: +30%"
		_:
			return "♥ 6 СЕРДЕЦ\nВРАГИ: ОБЫЧНЫЕ · УРОН 1\nСВЕТ/ВОЗДУХ: НОРМА"


func _refresh() -> void:
	for i in _buttons.size():
		var cur := i == _selected
		_buttons[i].add_theme_color_override("font_color", UiTheme.GOLD if cur else UiTheme.TEXT)
		_descs[i].add_theme_color_override("font_color", UiTheme.GOLD if cur else UiTheme.DIM)
		_stats[i].text = _stat_text(i)
		_tags[i].text = str(Game.DIFFICULTY_TAGS[i]) + (" · ВЫБРАНО" if cur else "")
		_tags[i].add_theme_color_override("font_color", UiTheme.ACCENT if cur else UiTheme.DIM)
		_cards[i].add_theme_stylebox_override("panel",
			UiTheme.panel_box(UiTheme.BG_SOFT,
				UiTheme.BORDER_HOT if cur else UiTheme.BORDER, 2))
	_start_btn.text = "НАЧАТЬ: %s" % Game.DIFFICULTY_NAMES[_selected]
	_summary.text = "%s — %d сердец. %s" % [
		Game.DIFFICULTY_NAMES[_selected],
		int(Game.DIFFICULTY_BALANCE[_selected]["player_hp"]),
		"Рекомендуемый уровень." if _selected == 1 else "Можно изменить только до старта.",
	]


func open() -> void:
	visible = true
	_committed = false
	_selected = clampi(Game.difficulty, 0, Game.DIFFICULTY_NAMES.size() - 1)
	_refresh()
	_start_btn.grab_focus()
	if get_tree() != null:
		get_tree().paused = true


func close_window() -> void:
	visible = false


func is_open() -> bool:
	return visible


func _select(index: int) -> void:
	_selected = clampi(index, 0, Game.DIFFICULTY_NAMES.size() - 1)
	_refresh()
	Audio.play("ui", -14.0)


func _confirm() -> void:
	_pick(_selected)


func _pick(index: int) -> void:
	if _committed:
		return
	_committed = true
	close_window()
	chosen.emit(index)


func _cancel() -> void:
	close_window()
	cancelled.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		_select(_selected - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		_select(_selected + 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or event.is_action_pressed("attack"):
		_confirm()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		_cancel()
		get_viewport().set_input_as_handled()
