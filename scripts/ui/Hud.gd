class_name Hud
extends Control
## Игровой интерфейс: сердца, мини-карта, подсказка взаимодействия, всплывающие сообщения,
## строка этажа и быстрый доступ к предметам.

var hearts_box: HBoxContainer
var minimap: Minimap
var map_panel: PanelContainer
var prompt_panel: PanelContainer
var prompt_label: Label
var banner_box: VBoxContainer
var banner_title: Label
var banner_sub: Label
var toast_box: VBoxContainer
var quick_box: HBoxContainer
var hint_label: Label
var difficulty_label: Label
var lamp_label: Label
var lamp_fill: ColorRect
var lamp_bg: ColorRect
var air_label: Label
var air_fill: ColorRect
var air_bg: ColorRect

var _world: World = null
var _banner_tween: Tween = null
var _prompt_bg: StyleBoxFlat = null
var _prompt_bg_ghost: StyleBoxFlat = null
var _prompt_ghosted := false


func _ready() -> void:
	UiTheme.fullscreen(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	Game.hp_changed.connect(_refresh_hp)
	Game.inventory_changed.connect(_refresh_quick)
	Game.toast_requested.connect(push_toast)
	Game.difficulty_changed.connect(_refresh_difficulty)
	_refresh_hp()
	_refresh_quick()


func _build() -> void:
	# сердца
	hearts_box = HBoxContainer.new()
	hearts_box.position = Vector2(26, 22)
	hearts_box.add_theme_constant_override("separation", 4)
	add_child(hearts_box)

	# заряд фонаря — главный ресурс выживания
	lamp_label = UiTheme.make_label("ФОНАРЬ: 100%", 13, Color(0.82, 0.78, 0.62))
	lamp_label.position = Vector2(28, 58)
	add_child(lamp_label)
	lamp_bg = ColorRect.new()
	lamp_bg.color = Color(0.08, 0.09, 0.09, 0.85)
	lamp_bg.position = Vector2(28, 78)
	lamp_bg.size = Vector2(120, 6)
	add_child(lamp_bg)
	lamp_fill = ColorRect.new()
	lamp_fill.color = Color(0.85, 0.66, 0.28)
	lamp_fill.position = Vector2(28, 78)
	lamp_fill.size = Vector2(120, 6)
	add_child(lamp_fill)

	air_label = UiTheme.make_label("ВОЗДУХ: 100%", 13, Color(0.68, 0.82, 0.76))
	air_label.position = Vector2(28, 90)
	add_child(air_label)
	air_bg = ColorRect.new()
	air_bg.color = Color(0.07, 0.09, 0.09, 0.85)
	air_bg.position = Vector2(28, 110)
	air_bg.size = Vector2(120, 6)
	add_child(air_bg)
	air_fill = ColorRect.new()
	air_fill.color = Color(0.42, 0.68, 0.56)
	air_fill.position = Vector2(28, 110)
	air_fill.size = Vector2(120, 6)
	add_child(air_fill)

	# мини-карта
	map_panel = UiTheme.make_panel(Color(0.05, 0.05, 0.06, 0.9), UiTheme.BORDER, 2)
	map_panel.position = Vector2(UiTheme.VW - 196, 20)
	add_child(map_panel)
	minimap = Minimap.new()
	map_panel.add_child(minimap)

	# строка этажа
	banner_box = VBoxContainer.new()
	banner_box.position = Vector2(UiTheme.VW * 0.5 - 260, 26)
	banner_box.custom_minimum_size = Vector2(520, 0)
	banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(banner_box)
	banner_title = UiTheme.make_label("КОРПУС Б", 22, UiTheme.TEXT)
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_title.custom_minimum_size = Vector2(520, 0)
	banner_box.add_child(banner_title)
	banner_sub = UiTheme.make_label("", 14, UiTheme.DIM)
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.custom_minimum_size = Vector2(520, 0)
	banner_box.add_child(banner_sub)

	# сложность текущей партии
	difficulty_label = UiTheme.make_label("", 14, UiTheme.GOLD)
	difficulty_label.position = Vector2(UiTheme.VW * 0.5 - 260, 78)
	difficulty_label.custom_minimum_size = Vector2(520, 0)
	difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(difficulty_label)
	_refresh_difficulty()

	# подсказка взаимодействия
	prompt_panel = UiTheme.make_panel(Color(0.05, 0.05, 0.06, 0.85), UiTheme.BORDER_HOT, 1)
	prompt_panel.position = Vector2(UiTheme.VW * 0.5 - 170, UiTheme.VH - 128)
	prompt_panel.custom_minimum_size = Vector2(340, 0)
	prompt_panel.size = Vector2(340, 40)
	add_child(prompt_panel)
	prompt_label = UiTheme.make_label("", 17, UiTheme.GOLD)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.custom_minimum_size = Vector2(310, 0)
	prompt_panel.add_child(prompt_label)
	prompt_panel.visible = false

	_prompt_bg = prompt_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if _prompt_bg != null:
		_prompt_bg_ghost = _prompt_bg.duplicate() as StyleBoxFlat
		_prompt_bg_ghost.bg_color = Color(0.05, 0.05, 0.06, 0.10)
		_prompt_bg_ghost.border_color = Color(
			UiTheme.BORDER_HOT.r, UiTheme.BORDER_HOT.g, UiTheme.BORDER_HOT.b, 0.35)

	# сообщения
	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(UiTheme.VW * 0.5 - 300, UiTheme.VH - 210)
	toast_box.custom_minimum_size = Vector2(600, 0)
	toast_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(toast_box)

	# быстрый доступ
	quick_box = HBoxContainer.new()
	quick_box.position = Vector2(24, UiTheme.VH - 74)
	quick_box.add_theme_constant_override("separation", 6)
	add_child(quick_box)

	hint_label = UiTheme.make_label(
		"[E] действие · [ЛКМ] луч фонаря · [I] инвентарь · [M] карта · [J] журнал · [Shift] бег · [F5] сохранить",
		13, Color(0.55, 0.53, 0.50))
	hint_label.position = Vector2(24, UiTheme.VH - 30)
	add_child(hint_label)


func bind_world(world: World) -> void:
	_world = world
	if minimap != null:
		minimap.set_map(world.map)
		_fit_map_panel()
		minimap.player = world.player
		minimap.companion = world.companion
		minimap.exits = []
		for e in world.get_tree().get_nodes_in_group("interactables"):
			if e is Interactable and e.kind == "exit":
				minimap.exits.append(e)
	if world.player != null and not world.player.prompt_changed.is_connected(set_prompt):
		world.player.prompt_changed.connect(set_prompt)
	show_banner(Levels.floor_name(world.floor_index), str(world.level.get("objective", "")))


## Панель мини-карты должна целиком влезать в экран: ширина схемы зависит от
## этажа, поэтому панель подгоняется по содержимому и прижимается к правому краю.
func _fit_map_panel() -> void:
	if map_panel == null or minimap == null:
		return
	map_panel.size = minimap.custom_minimum_size + Vector2(30, 30)
	map_panel.position = Vector2(UiTheme.VW - 20.0 - map_panel.size.x, 20.0)


## Если Вера оказывается под панелью интерфейса (мини-карта, подсказка),
## панель убирает фон, а не персонажа: его всегда должно быть видно.
func _update_hud_cover(delta: float) -> void:
	if map_panel == null or _world == null or not is_instance_valid(_world):
		return
	if not is_instance_valid(_world.player):
		return
	var cam: Camera2D = _world.player.camera
	if cam == null:
		return
	var screen_pos: Vector2 = cam.get_canvas_transform() * _world.player.global_position
	var body := Rect2(screen_pos + Vector2(-20, -56), Vector2(40, 60))
	var covered := Rect2(map_panel.position, map_panel.size).intersects(body)
	map_panel.modulate.a = move_toward(map_panel.modulate.a, 0.12 if covered else 1.0, delta * 12.0)

	if prompt_panel != null and _prompt_bg != null:
		var prompt_covered := prompt_panel.visible \
			and Rect2(prompt_panel.position, prompt_panel.size).intersects(body)
		if prompt_covered != _prompt_ghosted:
			_prompt_ghosted = prompt_covered
			prompt_panel.add_theme_stylebox_override(
				"panel", _prompt_bg_ghost if prompt_covered else _prompt_bg)


func _process(delta: float) -> void:
	_update_hud_cover(delta)
	if lamp_label != null:
		var ratio := Game.lamp_ratio()
		lamp_label.text = "ФОНАРЬ: %d%%" % int(round(ratio * 100.0))
		lamp_label.modulate = Color(1, 0.45, 0.35) if ratio < 0.18 else Color(1, 1, 1)
		lamp_fill.size.x = 120.0 * ratio
		lamp_fill.color = Color(0.85, 0.66, 0.28) if ratio >= 0.18 else Color(0.72, 0.24, 0.18)
	if air_label != null:
		var breath := Game.air_ratio()
		air_label.text = "ВОЗДУХ: %d%%" % int(round(breath * 100.0))
		air_label.modulate = Color(1, 0.4, 0.32) if breath < 0.22 else Color(1, 1, 1)
		air_fill.size.x = 120.0 * breath
		air_fill.color = Color(0.42, 0.68, 0.56) if breath >= 0.22 else Color(0.72, 0.24, 0.18)


func _refresh_hp() -> void:
	for c in hearts_box.get_children():
		c.queue_free()
	for i in Game.max_hp:
		var tr := TextureRect.new()
		tr.texture = Art.ui("heart" if i < Game.hp else "heart_empty")
		tr.custom_minimum_size = Vector2(26, 26)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hearts_box.add_child(tr)


func _refresh_quick() -> void:
	for c in quick_box.get_children():
		c.queue_free()
	for id in Game.inventory:
		var panel := UiTheme.make_panel(Color(0.06, 0.06, 0.07, 0.8), UiTheme.BORDER, 1)
		var tr := TextureRect.new()
		tr.texture = Items.icon_of(id)
		tr.custom_minimum_size = Vector2(36, 36)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		panel.add_child(tr)
		panel.tooltip_text = Items.name_of(id)
		quick_box.add_child(panel)


func _refresh_difficulty() -> void:
	if difficulty_label == null:
		return
	difficulty_label.text = "СЛОЖНОСТЬ: %s" % Game.difficulty_name()


func set_prompt(text: String) -> void:
	if text == "":
		prompt_panel.visible = false
	else:
		prompt_panel.visible = true
		prompt_label.text = text


func show_banner(title: String, sub: String) -> void:
	banner_title.text = title
	banner_sub.text = sub
	banner_box.modulate = Color(1, 1, 1, 1)
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_interval(5.0)
	_banner_tween.tween_property(banner_box, "modulate:a", 0.0, 1.5)


func push_toast(text: String) -> void:
	var l := UiTheme.make_label(text, 16, UiTheme.TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(600, 0)
	l.modulate = Color(0.95, 0.93, 0.88, 0.0)
	toast_box.add_child(l)
	while toast_box.get_child_count() > 4:
		toast_box.get_child(0).queue_free()
		await get_tree().process_frame
	var t := create_tween()
	t.tween_property(l, "modulate:a", 1.0, 0.2)
	t.tween_interval(2.6)
	t.tween_property(l, "modulate:a", 0.0, 0.9)
	t.tween_callback(l.queue_free)

