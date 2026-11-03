class_name EndUi
extends Control
## Экраны смерти и финала.

signal retry_requested
signal restart_requested
signal to_menu_requested

var _bg: TextureRect
var _overlay: ColorRect
var _title: Label
var _sub: Label
var _body: RichTextLabel
var _buttons: VBoxContainer
var _stats: Label


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
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_overlay = ColorRect.new()
	UiTheme.fullscreen(_overlay)
	_overlay.color = Color(0.02, 0.01, 0.01, 0.72)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	_title = UiTheme.make_label("КОНЕЦ", 68, Color(0.86, 0.16, 0.18))
	_title.position = Vector2(80, 96)
	add_child(_title)

	_sub = UiTheme.make_label("", 18, UiTheme.DIM)
	_sub.position = Vector2(84, 186)
	add_child(_sub)

	_body = UiTheme.make_rich("", 20, UiTheme.TEXT)
	_body.position = Vector2(84, 240)
	_body.custom_minimum_size = Vector2(760, 260)
	_body.size = Vector2(760, 260)
	add_child(_body)

	_stats = UiTheme.make_label("", 15, UiTheme.DIM)
	_stats.position = Vector2(84, 546)
	add_child(_stats)

	_buttons = VBoxContainer.new()
	_buttons.position = Vector2(84, 590)
	_buttons.add_theme_constant_override("separation", 6)
	add_child(_buttons)


func show_death() -> void:
	visible = true
	_bg.texture = Art.background("death")
	_bg.modulate = Color(0.6, 0.3, 0.3, 1)
	_overlay.color = Color(0.10, 0.01, 0.01, 0.72)
	_title.text = "ТЫ УМЕР"
	_title.add_theme_color_override("font_color", Color(0.86, 0.16, 0.18))
	_sub.text = "Корпус Б не отпускает."
	_body.text = "Холодный кафель. Далеко в коридоре — шаги, размеренные, как метроном.\n\nДоктор Барский останавливается над тобой, поправляет очки и говорит: «Ещё один не подписан. Ничего, я подожду»."
	_stats.text = "Корпус: %s · Время: %s · Призраков: %d · Смертей: %d" % [
		Levels.floor_name(Game.floor_index), Game.format_time(), Game.kills, Game.deaths]
	_clear_buttons()
	_add_button("ВСТАТЬ ЗАНОВО", func() -> void: retry_requested.emit())
	_add_button("В ГЛАВНОЕ МЕНЮ", func() -> void: to_menu_requested.emit())


func show_ending(id: String) -> void:
	var e := Dialogs.ending(id)
	visible = true
	_bg.texture = Art.background(str(e.get("art", "keyart")))
	_bg.modulate = Color(1, 1, 1, 1)
	_overlay.color = Color(0.01, 0.01, 0.02, 0.46)
	_title.text = str(e.get("title", "КОНЕЦ"))
	_title.add_theme_color_override("font_color", Color(0.90, 0.86, 0.80))
	_sub.text = "Финал"
	_body.text = str(e.get("text", ""))
	_stats.text = "Корпус: %s · Время: %s · Призраков: %d · Смертей: %d · Ранений: %d · Ранг: %s" % [
		Levels.floor_name(Game.floor_index), Game.format_time(), Game.kills, Game.deaths, Game.hits_taken,
		str(Game.last_shift_report.get("rank", "—"))]
	_clear_buttons()
	_add_button("ПРОЙТИ ЗАНОВО", func() -> void: restart_requested.emit())
	_add_button("В ГЛАВНОЕ МЕНЮ", func() -> void: to_menu_requested.emit())


func _clear_buttons() -> void:
	for c in _buttons.get_children():
		c.queue_free()


func _add_button(text: String, cb: Callable) -> void:
	var b := UiTheme.make_button(text, 22)
	b.pressed.connect(cb)
	_buttons.add_child(b)
	if _buttons.get_child_count() == 1:
		b.grab_focus()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		var n := _buttons.get_child_count()
		if n > 0:
			(_buttons.get_child(0) as Button).pressed.emit()
			get_viewport().set_input_as_handled()



