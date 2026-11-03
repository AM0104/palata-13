class_name PanelUi
extends Control
## Модальная панель: чтение записок и ввод кода на сейфе.

signal closed

var _panel: PanelContainer
var _title: Label
var _body: RichTextLabel
var _hint: Label
var _code_row: HBoxContainer
var _line: LineEdit
var _target: Interactable = null


func _ready() -> void:
	UiTheme.fullscreen(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	UiTheme.fullscreen(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = UiTheme.make_panel(UiTheme.BG, UiTheme.BORDER, 2)
	_panel.position = Vector2(280, 130)
	_panel.custom_minimum_size = Vector2(720, 460)
	_panel.size = Vector2(720, 460)
	add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_panel.add_child(col)

	_title = UiTheme.make_label("", 24, UiTheme.GOLD)
	col.add_child(_title)

	_body = UiTheme.make_rich("", 18, UiTheme.TEXT)
	_body.custom_minimum_size = Vector2(680, 300)
	_body.size = Vector2(680, 300)
	_body.scroll_active = true
	col.add_child(_body)

	_hint = UiTheme.make_label("", 15, UiTheme.DIM)
	col.add_child(_hint)

	_code_row = HBoxContainer.new()
	_code_row.add_theme_constant_override("separation", 10)
	col.add_child(_code_row)
	_line = LineEdit.new()
	_line.max_length = 8
	_line.placeholder_text = "код"
	_line.custom_minimum_size = Vector2(200, 40)
	_line.add_theme_font_size_override("font_size", 22)
	_code_row.add_child(_line)
	var ok := UiTheme.make_button("ВВЕСТИ", 18)
	ok.pressed.connect(_submit)
	_code_row.add_child(ok)

	var close := UiTheme.make_button("[E] закрыть", 18)
	close.pressed.connect(close_panel)
	col.add_child(close)


func show_text(title: String, body: String) -> void:
	_title.text = title
	_body.text = body
	_hint.text = "Записано в журнал. [J] — журнал."
	_code_row.visible = false
	_target = null
	visible = true


func show_code(it: Interactable) -> void:
	_target = it
	_title.text = str(it.data.get("label", "Сейф"))
	_body.text = str(it.data.get("panel_text", "Панель с четырьмя цифрами. Кнопки стёрты, но экран ещё светится."))
	_hint.text = str(it.data.get("hint", "Введите четыре цифры."))
	_code_row.visible = true
	_line.text = ""
	visible = true
	_line.grab_focus()


func close_panel() -> void:
	visible = false
	_target = null
	closed.emit()


func _submit() -> void:
	if _target == null or not is_instance_valid(_target):
		close_panel()
		return
	if _target.submit_code(_line.text.strip_edges()):
		Game.toast("Сейф открыт: %s" % str(_target.data.get("label", "")))
		close_panel()
	else:
		_line.text = ""


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("pause"):
		close_panel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and _code_row.visible == false:
		close_panel()
		get_viewport().set_input_as_handled()
