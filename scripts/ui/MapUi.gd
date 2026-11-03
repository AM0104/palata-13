class_name MapUi
extends Control
## Экран карты: план текущего этажа крупным планом и список пройденных этажей.

const MAX_W := 700.0
const MAX_H := 400.0

var map: Array = []
var player: Node2D = null
var companion: Node2D = null
var floor_index := 0
var cell := 12.0

var _panel: PanelContainer
var _title: Label
var _floors: VBoxContainer
var _canvas: Control
var _left: VBoxContainer
var _world: World = null
var _w := 0
var _h := 0


func _ready() -> void:
	UiTheme.fullscreen(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.86)
	UiTheme.fullscreen(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = UiTheme.make_panel(UiTheme.BG, UiTheme.BORDER, 2)
	_panel.position = Vector2(150, 118)
	_panel.custom_minimum_size = Vector2(980, 484)
	_panel.size = Vector2(980, 484)
	add_child(_panel)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 24)
	_panel.add_child(root)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	_left = left
	root.add_child(left)

	_title = UiTheme.make_label("КАРТА ЭТАЖА", 26, UiTheme.TEXT)
	left.add_child(_title)

	var canvas := Control.new()
	_canvas = canvas
	canvas.draw.connect(_draw_map.bind(canvas))
	left.add_child(canvas)

	var legend := UiTheme.make_label("красная точка — Миша · золото — выход · тёмно-красные — призраки", 14, UiTheme.DIM)
	left.add_child(legend)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.custom_minimum_size = Vector2(300, 0)
	root.add_child(right)
	right.add_child(UiTheme.make_label("ЭТАЖИ", 20, UiTheme.GOLD))
	_floors = VBoxContainer.new()
	_floors.add_theme_constant_override("separation", 6)
	right.add_child(_floors)
	right.add_child(UiTheme.make_label("Ниже — только вниз.\nВыше дороги нет.", 14, UiTheme.DIM))

	var close := UiTheme.make_button("[M] закрыть карту", 18)
	close.pressed.connect(func() -> void: visible = false)
	right.add_child(close)


func apply(world: World) -> void:
	_world = world
	map = world.map
	player = world.player
	companion = world.companion
	floor_index = world.floor_index
	_title.text = "КАРТА • %s" % Levels.floor_name(floor_index)
	_fit_canvas()
	for c in _floors.get_children():
		c.queue_free()
	for i in Levels.count():
		var visited := i <= floor_index
		var line := "%s  %s" % [Levels.floor_name(i), "— пройден" if i < floor_index else ("— здесь" if i == floor_index else "— внизу")]
		var l := UiTheme.make_label(line, 16, UiTheme.TEXT if visited else Color(0.35, 0.34, 0.33))
		_floors.add_child(l)
	if player != null and is_instance_valid(player):
		queue_redraw()


## Масштаб под текущий этаж: карты у этажей разного размера.
func _fit_canvas() -> void:
	_h = map.size()
	_w = 0
	for row in map:
		_w = maxi(_w, str(row).length())
	if _w <= 0 or _h <= 0 or _canvas == null:
		return
	cell = minf(MAX_W / float(_w), MAX_H / float(_h))
	_canvas.custom_minimum_size = Vector2(_w * cell, _h * cell)
	if _left != null:
		_left.custom_minimum_size = Vector2(_w * cell + 20, 0)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw_map(canvas: Control) -> void:
	var w := _w * cell
	var h := _h * cell
	canvas.draw_rect(Rect2(0, 0, w, h), Color(0.04, 0.04, 0.05), true)
	for y in map.size():
		var row := str(map[y])
		for x in row.length():
			if row[x] == "#":
				canvas.draw_rect(Rect2(x * cell, y * cell, cell, cell), Color(0.17, 0.17, 0.19), true)
			else:
				canvas.draw_rect(Rect2(x * cell + 0.5, y * cell + 0.5, cell - 1, cell - 1),
					Color(0.30, 0.29, 0.32), true)
	canvas.draw_rect(Rect2(0, 0, w, h), UiTheme.BORDER, false, 1.0)

	if _world == null or not is_instance_valid(_world):
		return
	for e in _world.get_tree().get_nodes_in_group("interactables"):
		if e is Interactable and e.kind == "exit":
			var p: Vector2 = e.global_position / World.TILE * cell
			canvas.draw_rect(Rect2(p.x - 4, p.y - 4, 8, 8), UiTheme.GOLD, true)
	for en in _world.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(en):
			var p: Vector2 = en.global_position / World.TILE * cell
			canvas.draw_circle(p, 3.0, Color(0.55, 0.12, 0.14, 0.85))
	if companion != null and is_instance_valid(companion):
		canvas.draw_circle(companion.global_position / World.TILE * cell, 4.0, Color(0.62, 0.64, 0.72))
	if player != null and is_instance_valid(player):
		var pp: Vector2 = player.global_position / World.TILE * cell
		canvas.draw_circle(pp, 5.0, Color(0.90, 0.30, 0.30))
		canvas.draw_arc(pp, 9.0, 0, TAU, 24, Color(0.9, 0.3, 0.3, 0.6), 1.5)


