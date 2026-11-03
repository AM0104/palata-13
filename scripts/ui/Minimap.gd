class_name Minimap
extends Control
## Схема горизонта в правом верхнем углу: комнаты, Вера, Клим, враги, выход.
## Размер этажа у каждого свой, поэтому масштаб ячейки подбирается под карту.

const MAX_W := 236.0
const MAX_H := 150.0

var map: Array = []
var player: Node2D = null
var companion: Node2D = null
var exits: Array = []
var cell := 3.6

var _w := 0
var _h := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Подогнать схему под карту любого размера.
func set_map(m: Array) -> void:
	map = m
	_h = map.size()
	_w = 0
	for row in map:
		_w = maxi(_w, str(row).length())
	if _w <= 0 or _h <= 0:
		return
	cell = minf(MAX_W / float(_w), MAX_H / float(_h))
	custom_minimum_size = Vector2(_w * cell, _h * cell)
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var w := _w * cell
	var h := _h * cell
	draw_rect(Rect2(0, 0, w, h), Color(0.04, 0.04, 0.05, 0.92), true)

	for y in map.size():
		var row := str(map[y])
		for x in row.length():
			if row[x] == "#":
				continue
			draw_rect(Rect2(x * cell, y * cell, cell, cell), Color(0.26, 0.25, 0.28, 0.9), true)

	for e in exits:
		if is_instance_valid(e):
			var ep: Vector2 = e.global_position / World.TILE * cell
			draw_rect(Rect2(ep.x - 2, ep.y - 2, 4, 4), UiTheme.GOLD, true)

	for en in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(en):
			continue
		var np: Vector2 = en.global_position / World.TILE * cell
		draw_circle(np, 1.6, Color(0.55, 0.12, 0.14, 0.9))

	if companion != null and is_instance_valid(companion):
		var cp: Vector2 = companion.global_position / World.TILE * cell
		draw_circle(cp, 2.0, Color(0.62, 0.64, 0.72))

	if player != null and is_instance_valid(player):
		var pp: Vector2 = player.global_position / World.TILE * cell
		draw_circle(pp, 2.6, Color(0.90, 0.30, 0.30))
		draw_arc(pp, 5.0, 0, TAU, 18, Color(0.9, 0.3, 0.3, 0.5), 1.0)

	draw_rect(Rect2(0, 0, w, h), Color(0.75, 0.72, 0.66, 0.55), false, 1.0)

