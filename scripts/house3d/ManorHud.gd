class_name ManorHud
extends CanvasLayer
## Интерфейс 3D-режима: цель, сердца, заряд фонаря, подсказки, записки, пауза, финалы.
## Работает при остановленном дереве (process_mode = ALWAYS), потому что записка и
## пауза ставят игру на паузу.

signal resume_requested
signal pause_requested
signal restart_requested
signal menu_requested
signal note_closed

const W := 1280
const H := 720

var _root: Control
var _objective: Label
var _sub: Label
var _hearts: Array[ColorRect] = []
var _hearts_label: Label
var _battery_fill: ColorRect
var _battery_label: Label
var _flash_label: Label
var _crosshair: Control
var _prompt: Label
var _toast: Label
var _hint: Label
var _damage: ColorRect
var _capture_hint: Label
var _note_panel: PanelContainer
var _note_title: Label
var _note_text: RichTextLabel
var _pause_panel: Control
var _death_panel: Control
var _win_panel: Control
var _win_text: Label
var _intro: Control
var _intro_title: Label
var _intro_sub: Label
var _toast_tween: Tween
var _intro_tween: Tween
var _damage_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build()
	clear_modals()


func _build() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.fullscreen(_root)
	add_child(_root)

	_objective = UiTheme.make_label("", 17, UiTheme.GOLD)
	_objective.position = Vector2(36, 24)
	_root.add_child(_objective)

	_sub = UiTheme.make_label("", 13, UiTheme.DIM)
	_sub.position = Vector2(36, 50)
	_root.add_child(_sub)

	# сердца
	var hlabel := UiTheme.make_label("СЕРДЦА", 11, UiTheme.DIM)
	hlabel.position = Vector2(1086, 22)
	_root.add_child(hlabel)
	_hearts_label = hlabel
	for i in 3:
		var r := ColorRect.new()
		r.position = Vector2(1088 + i * 22, 42)
		r.size = Vector2(14, 14)
		r.color = Color(0.55, 0.09, 0.11)
		_root.add_child(r)
		_hearts.append(r)

	# фонарь
	_battery_label = UiTheme.make_label("ФОНАРЬ", 11, UiTheme.DIM)
	_battery_label.position = Vector2(1000, 22)
	_root.add_child(_battery_label)
	var back := ColorRect.new()
	back.position = Vector2(1000, 42)
	back.size = Vector2(70, 8)
	back.color = Color(0.18, 0.17, 0.16)
	_root.add_child(back)
	_battery_fill = ColorRect.new()
	_battery_fill.position = Vector2(1000, 42)
	_battery_fill.size = Vector2(70, 8)
	_battery_fill.color = Color(0.95, 0.82, 0.4)
	_root.add_child(_battery_fill)

	_flash_label = UiTheme.make_label("", 11, UiTheme.DIM)
	_flash_label.position = Vector2(1000, 54)
	_root.add_child(_flash_label)

	# прицел
	_crosshair = Control.new()
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.position = Vector2(W / 2 - 6, H / 2 - 6)
	_root.add_child(_crosshair)
	var dot := ColorRect.new()
	dot.position = Vector2(5, 5)
	dot.size = Vector2(2, 2)
	dot.color = Color(0.95, 0.93, 0.88, 0.85)
	_crosshair.add_child(dot)
	for i in 4:
		var tick := ColorRect.new()
		tick.color = Color(0.95, 0.93, 0.88, 0.35)
		match i:
			0:
				tick.position = Vector2(5, 0)
				tick.size = Vector2(2, 3)
			1:
				tick.position = Vector2(5, 9)
				tick.size = Vector2(2, 3)
			2:
				tick.position = Vector2(0, 5)
				tick.size = Vector2(3, 2)
			3:
				tick.position = Vector2(9, 5)
				tick.size = Vector2(3, 2)
		_crosshair.add_child(tick)

	_prompt = UiTheme.make_label("", 16, UiTheme.TEXT)
	_prompt.position = Vector2(240, H / 2 + 36)
	_prompt.size = Vector2(800, 26)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_prompt)

	_hint = UiTheme.make_label(
		"Мышь — осмотреться   ·   WASD — идти   ·   Shift — бежать   ·   F — фонарь   ·   E — действие   ·   Esc — пауза",
		12, Color(0.62, 0.6, 0.56, 0.8))
	_hint.position = Vector2(36, 686)
	_root.add_child(_hint)

	_capture_hint = UiTheme.make_label("ЛКМ — захватить мышь   ·   мышь — осмотреться", 14, UiTheme.GOLD)
	_capture_hint.position = Vector2(240, 636)
	_capture_hint.size = Vector2(800, 24)
	_capture_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_capture_hint.visible = false
	_root.add_child(_capture_hint)

	_toast = UiTheme.make_label("", 18, UiTheme.GOLD)
	_toast.position = Vector2(240, 112)
	_toast.size = Vector2(800, 28)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_root.add_child(_toast)

	# интро рисуется под модальными окнами: пауза и записка должны быть поверх него
	_build_intro()
	_build_note()
	_build_pause()
	_build_death()
	_build_win()

	_damage = ColorRect.new()
	_damage.color = Color(0.55, 0.02, 0.03, 0.0)
	_damage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.fullscreen(_damage)
	_root.add_child(_damage)
	_root.move_child(_damage, 0)


func _build_note() -> void:
	_note_panel = UiTheme.make_panel()
	_note_panel.position = Vector2(250, 110)
	_note_panel.size = Vector2(780, 500)
	_note_panel.custom_minimum_size = Vector2(780, 500)
	_note_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_note_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_note_panel.add_child(box)

	_note_title = UiTheme.make_label("", 24, UiTheme.GOLD)
	box.add_child(_note_title)

	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.16)
	line.custom_minimum_size = Vector2(0, 1)
	box.add_child(line)

	_note_text = UiTheme.make_rich("", 18, UiTheme.TEXT)
	_note_text.custom_minimum_size = Vector2(740, 380)
	_note_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_note_text)

	var close_hint := UiTheme.make_label("E или Esc — закрыть", 13, UiTheme.DIM)
	box.add_child(close_hint)


func _build_pause() -> void:
	_pause_panel = Control.new()
	_pause_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.fullscreen(_pause_panel)
	_root.add_child(_pause_panel)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.015, 0.78)
	UiTheme.fullscreen(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_panel.add_child(dim)

	var title := UiTheme.make_label("ПАУЗА", 46, Color(0.93, 0.9, 0.86))
	title.position = Vector2(96, 120)
	_pause_panel.add_child(title)

	var sub := UiTheme.make_label("Дом ждёт. Он никуда не спешит.", 15, UiTheme.DIM)
	sub.position = Vector2(99, 180)
	_pause_panel.add_child(sub)

	var box := VBoxContainer.new()
	box.position = Vector2(96, 230)
	box.add_theme_constant_override("separation", 6)
	_pause_panel.add_child(box)

	var b_res := UiTheme.make_button("ПРОДОЛЖИТЬ", 24)
	b_res.pressed.connect(func() -> void: resume_requested.emit())
	box.add_child(b_res)

	var vol_label := UiTheme.make_label("ГРОМКОСТЬ", 13, UiTheme.GOLD)
	box.add_child(vol_label)
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = Settings.volume
	vol.custom_minimum_size = Vector2(280, 22)
	vol.value_changed.connect(func(v: float) -> void: Settings.set_volume(v))
	box.add_child(vol)

	var sens_label := UiTheme.make_label("ЧУВСТВИТЕЛЬНОСТЬ МЫШИ", 13, UiTheme.GOLD)
	box.add_child(sens_label)
	var sens := HSlider.new()
	sens.min_value = Settings.MIN_SENSITIVITY
	sens.max_value = Settings.MAX_SENSITIVITY
	sens.step = 0.1
	sens.value = Settings.mouse_sensitivity
	sens.custom_minimum_size = Vector2(280, 22)
	sens.value_changed.connect(func(v: float) -> void: Settings.set_mouse_sensitivity(v))
	box.add_child(sens)

	var fs := CheckButton.new()
	fs.text = "ПОЛНЫЙ ЭКРАН"
	fs.add_theme_font_size_override("font_size", 16)
	fs.add_theme_color_override("font_color", UiTheme.TEXT)
	fs.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	fs.button_pressed = Settings.is_fullscreen()
	fs.toggled.connect(func(on: bool) -> void: Settings.set_fullscreen(on))
	Settings.fullscreen_changed.connect(func(on: bool) -> void: fs.set_pressed_no_signal(on))
	box.add_child(fs)

	var sh := CheckButton.new()
	sh.text = "ТЕНИ"
	sh.add_theme_font_size_override("font_size", 16)
	sh.add_theme_color_override("font_color", UiTheme.TEXT)
	sh.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sh.button_pressed = Settings.shadows
	sh.toggled.connect(func(on: bool) -> void: Settings.set_shadows(on))
	box.add_child(sh)

	var fg := CheckButton.new()
	fg.text = "ТУМАН"
	fg.add_theme_font_size_override("font_size", 16)
	fg.add_theme_color_override("font_color", UiTheme.TEXT)
	fg.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	fg.button_pressed = Settings.fog
	fg.toggled.connect(func(on: bool) -> void: Settings.set_fog(on))
	box.add_child(fg)

	var b_menu := UiTheme.make_button("В ГЛАВНОЕ МЕНЮ", 20)
	b_menu.pressed.connect(func() -> void: menu_requested.emit())
	box.add_child(b_menu)

	var b_restart := UiTheme.make_button("НАЧАТЬ ЗАНОВО", 20)
	b_restart.pressed.connect(func() -> void: restart_requested.emit())
	box.add_child(b_restart)

	var credit := UiTheme.make_label(
		"Карта «Haunted House» — Amy (Sketchfab), CC BY 4.0. Остальное сделано для проекта.",
		11, Color(0.5, 0.48, 0.45, 0.9))
	credit.position = Vector2(96, 660)
	_pause_panel.add_child(credit)


func _build_death() -> void:
	_death_panel = Control.new()
	_death_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.fullscreen(_death_panel)
	_root.add_child(_death_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.005, 0.008, 0.9)
	UiTheme.fullscreen(bg)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_death_panel.add_child(bg)

	var title := UiTheme.make_label("ТЕБЯ БОЛЬШЕ НЕТ", 56, Color(0.7, 0.12, 0.14))
	title.position = Vector2(96, 150)
	_death_panel.add_child(title)

	var sub := UiTheme.make_label("Хозяйка дома осталась довольна.", 18, UiTheme.DIM)
	sub.position = Vector2(100, 226)
	_death_panel.add_child(sub)

	var box := VBoxContainer.new()
	box.position = Vector2(96, 290)
	box.add_theme_constant_override("separation", 6)
	_death_panel.add_child(box)

	var b_retry := UiTheme.make_button("ЕЩЁ РАЗ", 24)
	b_retry.pressed.connect(func() -> void: restart_requested.emit())
	box.add_child(b_retry)

	var b_menu := UiTheme.make_button("В ГЛАВНОЕ МЕНЮ", 20)
	b_menu.pressed.connect(func() -> void: menu_requested.emit())
	box.add_child(b_menu)


func _build_win() -> void:
	_win_panel = Control.new()
	_win_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.fullscreen(_win_panel)
	_root.add_child(_win_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.025, 0.02, 0.92)
	UiTheme.fullscreen(bg)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_win_panel.add_child(bg)

	var title := UiTheme.make_label("ТЫ ВЫШЕЛ", 56, Color(0.82, 0.74, 0.5))
	title.position = Vector2(96, 150)
	_win_panel.add_child(title)

	_win_text = UiTheme.make_label("", 17, UiTheme.TEXT)
	_win_text.position = Vector2(100, 232)
	_win_text.size = Vector2(760, 180)
	_win_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_win_panel.add_child(_win_text)

	var box := VBoxContainer.new()
	box.position = Vector2(96, 430)
	box.add_theme_constant_override("separation", 6)
	_win_panel.add_child(box)

	var b_again := UiTheme.make_button("ЕЩЁ РАЗ", 22)
	b_again.pressed.connect(func() -> void: restart_requested.emit())
	box.add_child(b_again)

	var b_menu := UiTheme.make_button("В ГЛАВНОЕ МЕНЮ", 22)
	b_menu.pressed.connect(func() -> void: menu_requested.emit())
	box.add_child(b_menu)


func _build_intro() -> void:
	_intro = Control.new()
	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.fullscreen(_intro)
	_root.add_child(_intro)

	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.012, 0.016, 1.0)
	UiTheme.fullscreen(bg)
	# ИНТРО НЕ ДОЛЖНО ЛОВИТЬ МЫШЬ: иначе первые секунды камера не вращается.
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.add_child(bg)

	_intro_title = UiTheme.make_label("ОСОБНЯК «ТИХИЙ БОР»", 40, Color(0.9, 0.87, 0.8))
	_intro_title.position = Vector2(96, 250)
	_intro_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.add_child(_intro_title)

	_intro_sub = UiTheme.make_label("", 17, UiTheme.DIM)
	_intro_sub.position = Vector2(100, 320)
	_intro_sub.size = Vector2(820, 120)
	_intro_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.add_child(_intro_sub)

	var hint := UiTheme.make_label("Мышь — осмотреться · WASD — идти · E — действие", 13, UiTheme.GOLD)
	hint.position = Vector2(100, 470)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.add_child(hint)


# --- данные ----------------------------------------------------------------

func set_objective(text: String, sub: String = "") -> void:
	_objective.text = text
	_sub.text = sub


func set_hearts(value: int) -> void:
	for i in _hearts.size():
		_hearts[i].color = Color(0.62, 0.1, 0.12) if i < value else Color(0.16, 0.11, 0.12)


func set_battery(value: float) -> void:
	var frac := clampf(value / 100.0, 0.0, 1.0)
	_battery_fill.size.x = 70.0 * frac
	if frac < 0.2:
		_battery_fill.color = Color(0.85, 0.25, 0.2)
	elif frac < 0.5:
		_battery_fill.color = Color(0.9, 0.62, 0.25)
	else:
		_battery_fill.color = Color(0.95, 0.82, 0.4)


func set_flashlight(on: bool) -> void:
	_flash_label.text = "ВКЛ" if on else "ВЫКЛ"
	_flash_label.add_theme_color_override("font_color", UiTheme.GOLD if on else UiTheme.DIM)


## Подсказка «ЛКМ — захватить мышь», когда курсор не захвачен.
func set_capture_hint(v: bool) -> void:
	if _capture_hint != null:
		_capture_hint.visible = v


func set_hud_visible(v: bool) -> void:
	_objective.visible = v
	_sub.visible = v
	_hint.visible = v
	_battery_label.visible = v
	_battery_fill.visible = v
	_flash_label.visible = v
	_hearts_label.visible = v
	for h in _hearts:
		h.visible = v
	if not v:
		_toast.modulate.a = 0.0


## Красная пелена на удар или на пробуждение Хозяйки.
func flash_damage(strength: float = 0.6) -> void:
	if _damage == null:
		return
	if _damage_tween != null and _damage_tween.is_valid():
		_damage_tween.kill()
	_damage.color.a = clampf(strength, 0.0, 0.85)
	_damage_tween = create_tween()
	_damage_tween.tween_property(_damage, "color:a", 0.0, 1.0)


func show_prompt(text: String) -> void:
	_prompt.text = text
	_prompt.visible = text != ""


func toast(text: String, seconds: float = 3.2) -> void:
	if _death_panel.visible or _win_panel.visible:
		return
	_toast.text = text
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 1.2)


func show_intro(sub: String, seconds: float = 4.0) -> void:
	_intro.visible = true
	_intro.modulate.a = 1.0
	_intro_sub.text = sub
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.tween_interval(seconds)
	_intro_tween.tween_property(_intro, "modulate:a", 0.0, 1.6)
	_intro_tween.tween_callback(func() -> void: _intro.visible = false)


func _skip_intro() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro.visible = false


func show_note(title: String, body: String) -> void:
	_note_title.text = title
	_note_text.text = body
	_note_panel.visible = true
	_crosshair.visible = false
	_prompt.visible = false


func close_note() -> void:
	if not _note_panel.visible:
		return
	_note_panel.visible = false
	_crosshair.visible = true
	note_closed.emit()


func note_open() -> bool:
	return _note_panel.visible


func show_pause() -> void:
	set_hud_visible(false)
	set_capture_hint(false)
	_pause_panel.visible = true
	_crosshair.visible = false
	_prompt.visible = false


func hide_pause() -> void:
	set_hud_visible(true)
	_pause_panel.visible = false
	_crosshair.visible = true


func show_death() -> void:
	set_hud_visible(false)
	set_capture_hint(false)
	_death_panel.visible = true
	_crosshair.visible = false
	_prompt.visible = false


func show_win(text: String) -> void:
	_win_text.text = text
	set_hud_visible(false)
	set_capture_hint(false)
	_win_panel.visible = true
	_crosshair.visible = false
	_prompt.visible = false


func clear_modals() -> void:
	_note_panel.visible = false
	_pause_panel.visible = false
	_death_panel.visible = false
	_win_panel.visible = false
	_intro.visible = false
	set_hud_visible(true)
	_crosshair.visible = true
	_prompt.visible = false
	show_prompt("")


func modal_open() -> bool:
	return _note_panel.visible or _pause_panel.visible or _death_panel.visible or _win_panel.visible


# --- ввод ------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	# Любая клавиша или клик пропускают вступление.
	if _intro.visible:
		if (event is InputEventKey and event.pressed) \
				or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
			_skip_intro()
		return
	if _note_panel.visible:
		if event.is_action_pressed("pause") or event.is_action_pressed("interact"):
			close_note()
			get_viewport().set_input_as_handled()
		return
	if _death_panel.visible or _win_panel.visible:
		return
	if _pause_panel.visible:
		if event.is_action_pressed("pause"):
			resume_requested.emit()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		pause_requested.emit()
		get_viewport().set_input_as_handled()
