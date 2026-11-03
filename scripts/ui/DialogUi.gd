class_name DialogUi
extends Control
## Диалоги: портрет, имя, реплика с эффектом печатной машинки, выборы ответов.
##
## Выборы ответов работают и мышью, и клавиатурой: ↑/↓ (или W/S) — выделение,
## Enter/E/Пробел — подтверждение. Мышиные события здесь намеренно НЕ помечаются
## как обработанные, иначе кнопки выбора не получат клик (левый клик — это ещё и
## действие "attack").

signal finished

var steps: Array = []
var idx := 0
var world: World = null

var panel: PanelContainer
var portrait: TextureRect
var name_label: Label
var role_label: Label
var portrait_frame: PanelContainer
var text_label: RichTextLabel
var arrow: Label
var choice_box: VBoxContainer
var _typing := false
var _type_tween: Tween = null

var _choice_buttons: Array[Button] = []
var _choice_data: Array = []
var _choice_index := 0


func _ready() -> void:
	UiTheme.fullscreen(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	UiTheme.fullscreen(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	panel = UiTheme.make_panel(Color(0.04, 0.04, 0.05, 0.94), UiTheme.BORDER, 2)
	panel.position = Vector2(140, 410)
	panel.custom_minimum_size = Vector2(1000, 280)
	panel.size = Vector2(1000, 280)
	add_child(panel)

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	portrait_frame = UiTheme.make_panel(Color(0.025, 0.03, 0.03, 0.98), UiTheme.BORDER, 2)
	var frame_style := UiTheme.panel_box(Color(0.025, 0.03, 0.03, 0.98), UiTheme.BORDER, 2)
	frame_style.content_margin_left = 2
	frame_style.content_margin_right = 2
	frame_style.content_margin_top = 2
	frame_style.content_margin_bottom = 2
	portrait_frame.add_theme_stylebox_override("panel", frame_style)
	portrait_frame.custom_minimum_size = Vector2(184, 244)
	box.add_child(portrait_frame)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(180, 240)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait_frame.add_child(portrait)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.custom_minimum_size = Vector2(770, 0)
	box.add_child(right)

	name_label = UiTheme.make_label("", 19, UiTheme.GOLD)
	right.add_child(name_label)

	role_label = UiTheme.make_label("", 12, UiTheme.DIM)
	right.add_child(role_label)

	text_label = UiTheme.make_rich("", 19, UiTheme.TEXT)
	text_label.custom_minimum_size = Vector2(770, 150)
	text_label.size = Vector2(770, 150)
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(text_label)

	arrow = UiTheme.make_label("▼", 18, UiTheme.ACCENT)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	arrow.custom_minimum_size = Vector2(770, 0)
	arrow.visible = false
	right.add_child(arrow)

	# Список выборов создаётся последним — он должен быть поверх панели,
	# иначе панель перехватывает клики по нижним вариантам ответа.
	choice_box = VBoxContainer.new()
	choice_box.position = Vector2(180, 244)
	choice_box.custom_minimum_size = Vector2(920, 0)
	choice_box.add_theme_constant_override("separation", 6)
	add_child(choice_box)


func start(id: String, world_ref: World) -> void:
	world = world_ref
	steps = Dialogs.get_dialog(id)
	idx = 0
	_clear_choices()
	if steps.is_empty():
		_close()
		return
	visible = true
	_show()


func _show() -> void:
	if idx < 0 or idx >= steps.size():
		_close()
		return
	var s: Dictionary = steps[idx]
	if s.has("label"):
		idx += 1
		_show()
		return
	if s.has("goto"):
		_jump(str(s["goto"]))
		return
	if s.has("end"):
		_close()
		return
	if s.has("do"):
		_apply(s["do"])
		idx += 1
		_show()
		return
	if s.has("choice"):
		_show_choices(s["choice"])
		return
	if s.has("text"):
		_show_line(s)
		return
	idx += 1
	_show()


func _apply(do: Variant) -> void:
	if not (do is Dictionary):
		return
	var d: Dictionary = do
	if d.has("flag"):
		Game.set_flag(str(d["flag"]))
	if d.has("flag2"):
		Game.set_flag(str(d["flag2"]))
	if d.has("item"):
		var item := str(d["item"])
		if Game.add_item(item):
			Game.toast("Получено: %s" % Items.name_of(item))
	if d.has("note"):
		var arr: Array = d["note"]
		if arr.size() >= 2:
			Game.add_note(str(arr[0]), str(arr[1]))
	if d.has("toast"):
		Game.toast(str(d["toast"]))
	if d.has("action") and world != null and is_instance_valid(world):
		world.handle_action(str(d["action"]))
	if d.has("ending"):
		if world != null:
			world.ending_requested.emit(str(d["ending"]))


func _jump(label: String) -> void:
	for i in steps.size():
		var s: Dictionary = steps[i]
		if s.has("label") and str(s["label"]) == label:
			idx = i + 1
			_show()
			return
	idx += 1
	_show()


func _show_line(s: Dictionary) -> void:
	_clear_choices()
	var who := str(s.get("who", ""))
	var shown_name := str(s.get("name", ""))
	if who == "":
		portrait.visible = true
		portrait.texture = Art.background("dialog")
		name_label.text = ""
		role_label.text = ""
	else:
		portrait.visible = true
		portrait.texture = Art.portrait(who)
		name_label.text = shown_name
		role_label.text = Dialogs.role_of(who)
	var text := str(s.get("text", ""))
	text_label.text = text
	text_label.visible_characters = 0
	_typing = true
	arrow.visible = false
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	var dur := maxf(0.3, float(text.length()) * 0.022)
	_type_tween = create_tween()
	_type_tween.tween_property(text_label, "visible_characters", text.length(), dur)
	_type_tween.tween_callback(func() -> void:
		_typing = false
		arrow.visible = true)


func _show_choices(choices: Variant) -> void:
	_clear_choices()
	arrow.visible = false
	_typing = false
	text_label.visible_characters = -1
	if not (choices is Array) or (choices as Array).is_empty():
		idx += 1
		_show()
		return
	var n := 0
	for c in (choices as Array):
		if not (c is Dictionary):
			continue
		var cd: Dictionary = c
		var need_flag := str(cd.get("if_flag", ""))
		if need_flag != "" and not Game.flag(need_flag):
			continue
		var deny_flag := str(cd.get("if_not_flag", ""))
		if deny_flag != "" and Game.flag(deny_flag):
			continue
		var b := UiTheme.make_button("%d. %s" % [n + 1, str(cd.get("text", "..."))], 18)
		b.custom_minimum_size = Vector2(880, 0)
		b.focus_mode = Control.FOCUS_ALL
		var ci := n
		b.pressed.connect(func() -> void: _choose(ci))
		b.focus_entered.connect(func() -> void: _select(ci, false))
		b.mouse_entered.connect(func() -> void: _select(ci, true))
		choice_box.add_child(b)
		_choice_buttons.append(b)
		_choice_data.append(cd)
		n += 1
	if _choice_buttons.is_empty():
		idx += 1
		_show()
		return
	var hint := UiTheme.make_label("↑ ↓ — выбор   ·   Enter — подтвердить", 15, UiTheme.DIM)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice_box.add_child(hint)
	_select(0, true)


func _has_choices() -> bool:
	return not _choice_buttons.is_empty()


func _select(i: int, grab: bool) -> void:
	if _choice_buttons.is_empty():
		return
	_choice_index = clampi(i, 0, _choice_buttons.size() - 1)
	if not grab:
		return
	var b := _choice_buttons[_choice_index]
	if is_instance_valid(b) and not b.has_focus():
		b.grab_focus()


func _move_choice(step: int) -> void:
	if _choice_buttons.is_empty():
		return
	var n := _choice_buttons.size()
	_select(posmod(_choice_index + step, n), true)
	Audio.play("ui", -14.0)


func _confirm_choice() -> void:
	if _choice_buttons.is_empty():
		return
	_choose(_choice_index)


func _choose(i: int) -> void:
	if i < 0 or i >= _choice_data.size():
		return
	var cd: Dictionary = _choice_data[i]
	_clear_choices()
	Audio.play("ui_back", -8.0)
	_apply(cd)
	if cd.has("goto"):
		_jump(str(cd["goto"]))
	else:
		idx += 1
		_show()


func _clear_choices() -> void:
	_choice_buttons.clear()
	_choice_data.clear()
	_choice_index = 0
	for c in choice_box.get_children():
		choice_box.remove_child(c)
		c.queue_free()


func _advance() -> void:
	if _has_choices():
		return
	if _typing:
		if _type_tween != null and _type_tween.is_valid():
			_type_tween.kill()
		text_label.visible_characters = -1
		_typing = false
		arrow.visible = true
		return
	idx += 1
	_show()


func _close() -> void:
	visible = false
	_clear_choices()
	finished.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.echo:
		return

	# --- режим выбора ответа ---
	if _has_choices():
		if event is InputEventKey:
			if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
				_move_choice(-1)
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
				_move_choice(1)
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or event.is_action_pressed("attack"):
				_confirm_choice()
				get_viewport().set_input_as_handled()
		# Мышь не перехватываем: клик по кнопке обрабатывает сама кнопка.
		return

	# --- режим реплики ---
	if event is InputEventKey:
		if event.is_action_pressed("interact") or event.is_action_pressed("attack") \
				or event.is_action_pressed("pause") or event.is_action_pressed("ui_accept"):
			_advance()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		get_viewport().set_input_as_handled()
