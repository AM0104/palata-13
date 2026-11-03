class_name DoorGeom
extends RefCounted
## Геометрия двери: где в стене проём и что именно перекрывает запертая дверь.
##
## Дверь задаётся позицией и полем «block» — размером проёма в тайлах [w, h], а если
## в данных есть поле «gap» [x, y, w, h], проём берётся прямо оттуда — это точный
## прямоугольник пола, который перекрывает створка. По карте вокруг проёма считаются
## два прямоугольника:
##
##   gap     — проём: полоса пола, зажатая кладкой с торцов. Её рисует текстура двери,
##             и по ней проходит игрок, когда дверь открыта;
##   blocker — прямоугольник, который перекрывает запертая дверь: проём, протянутый
##             вглубь прохода до следующей кладки. Щелей по бокам не остаётся.
##
## Всё в целых тайлах — текстура ложится ровно по тайлам пола (32 px).

const TILE := 32
const MAX_RUN := 32      ## предел протяжки преграды (тайлы)
const SEEK := 4          ## где ищем кладку рядом с дверью (тайлы)

var tx := 0
var ty := 0
var w := 1               ## длина проёма вдоль стены (тайлы)
var h := 1               ## толщина проёма в стене (тайлы)
var vertical := false    ## проём в вертикальной стене: створ длинный по Y
var double := false      ## двустворчатая: длинная сторона от 40 px
var gap := Rect2i()
var blocker := Rect2i()
var center := Vector2()  ## центр проёма в пикселях — там стоит объект двери
var open_dir := Vector2i.ZERO  ## куда распахивается высокая дверь (по осям)
var valid := true
var note := ""


static func create(map: Array, e: Dictionary) -> DoorGeom:
	var g := DoorGeom.new()
	g._compute(map, e)
	return g


static func _solid(map: Array, x: int, y: int) -> bool:
	if y < 0 or y >= map.size():
		return true
	var row := str(map[y])
	if x < 0 or x >= row.length():
		return true
	return row[x] == "#"


func _compute(map: Array, e: Dictionary) -> void:
	tx = int(floor(float(e.get("x", 0))))
	ty = int(floor(float(e.get("y", 0))))
	var blk: Array = e.get("block", [1, 1])
	w = maxi(1, int(blk[0]) if blk.size() > 0 else 1)
	h = maxi(1, int(blk[1]) if blk.size() > 1 else 1)
	vertical = h > w
	double = (h if vertical else w) * TILE >= 40

	var declared: Array = e.get("gap", [])
	if declared.size() == 4:
		_use(Rect2i(int(declared[0]), int(declared[1]),
			maxi(1, int(declared[2])), maxi(1, int(declared[3]))))
		if map.is_empty():
			blocker = gap
			valid = false
			note = "нет карты"
			return
		blocker = _seal(map, gap, vertical)
		_pick_open_dir(map)
		_validate(map)
		return

	if map.is_empty():
		valid = false
		note = "нет карты"
		gap = Rect2i(tx - w / 2, ty - h / 2, w, h)
		blocker = gap
		center = _px(gap)
		return

	gap = _find_gap(map)
	_use(gap)
	blocker = _seal(map, gap, vertical)
	_pick_open_dir(map)
	_validate(map)


## Проём найден: от него зависят и размеры полотна, и сторона поворота.
func _use(r: Rect2i) -> void:
	gap = r
	w = r.size.x
	h = r.size.y
	vertical = h > w
	double = (h if vertical else w) * TILE >= 40
	center = _px(r)


## Высокая дверь распахивается в ту сторону, где за проёмом больше места: створка
## поворачивается в плоскости пола и встаёт поперёк стены, а не складывается.
func _pick_open_dir(map: Array) -> void:
	if map.is_empty() or not tall():
		return
	var a := _run_free(map, -1)
	var b := _run_free(map, 1)
	if vertical:
		open_dir = Vector2i(-1, 0) if a > b else Vector2i(1, 0)
	else:
		open_dir = Vector2i(0, -1) if a > b else Vector2i(0, 1)


func tall() -> bool:
	return gap.size.y > gap.size.x


## Сколько тайлов пола тянется от проёма поперёк стены в сторону dir.
func _run_free(map: Array, dir: int) -> int:
	var n := 0
	while n < MAX_RUN:
		var step := n + 1
		if gap.size.x >= gap.size.y:
			var y := (gap.position.y - step) if dir < 0 else (gap.position.y + gap.size.y - 1 + step)
			if not _all_floor(map, Rect2i(gap.position.x, y, gap.size.x, 1)):
				return n
		else:
			var x := (gap.position.x - step) if dir < 0 else (gap.position.x + gap.size.x - 1 + step)
			if not _all_floor(map, Rect2i(x, gap.position.y, 1, gap.size.y)):
				return n
		n += 1
	return n


func _validate(map: Array) -> void:
	if not _all_floor(map, gap):
		valid = false
		note = "проём вне пола"
	elif not _ends_solid(map, gap):
		valid = false
		note = "рядом с дверью нет проёма в стене"
	elif blocker.size.x < gap.size.x or blocker.size.y < gap.size.y:
		valid = false
		note = "проём не перекрывается целиком"


func _px(r: Rect2i) -> Vector2:
	return Vector2(float(r.position.x) * TILE + float(r.size.x) * TILE * 0.5,
		float(r.position.y) * TILE + float(r.size.y) * TILE * 0.5)


# =============================================================================
#  ПРОЁМ
# =============================================================================

## Проём — полоса пола, зажатая кладкой с торцов. Перебираем полосы разной длины
## и обеих ориентаций около двери: годится та, что лежит на полу, упирается торцами
## в кладку и стоит ближе к двери.
func _find_gap(map: Array) -> Rect2i:
	var best := Rect2i()
	var best_score := -1
	for vert in [false, true]:
		for span in _spans(vert):
			for d in range(-SEEK, SEEK + 1):
				var r := _probe(vert, span, d)
				if r.position.x < 0 or r.position.y < 0:
					continue
				if not _all_floor(map, r):
					continue
				if not _ends_solid(map, r):
					continue
				var block := _seal(map, r, vert)
				if not _all_floor(map, block) or not _covers(block, r):
					continue
				var score := _score(map, r, vert, span, block)
				if score > best_score:
					best_score = score
					best = r
	if best.size.x > 0:
		return best
	# запасной вариант: полоса пола у кладки
	for vert in [false, true]:
		for span in _spans(vert):
			for d in range(-SEEK, SEEK + 1):
				var r := _probe(vert, span, d)
				if r.position.x < 0 or r.position.y < 0 or not _all_floor(map, r):
					continue
				if _ends_solid(map, r):
					return r
	valid = false
	note = "рядом с дверью нет проёма в стене"
	return Rect2i(tx - w / 2, ty - h / 2, w, h)


## Длины полос: заявленная и соседние, не короче заявленной.
func _spans(vert: bool) -> Array:
	var declared := h if vert else w
	var out: Array = []
	for s_v in [declared, declared + 1, declared + 2, declared - 1]:
		var s: int = int(s_v)
		if s >= 1 and s <= 8 and not out.has(s):
			out.append(s)
	return out


## Полоса длиной span, сдвинутая на d поперёк стены.
func _probe(vert: bool, span: int, d: int) -> Rect2i:
	if vert:
		return Rect2i(tx + d, ty - span / 2, 1, span)
	return Rect2i(tx - span / 2, ty + d, span, 1)


## Полоса зажата кладкой с торцов — значит, это проём в стене, а не отрезок коридора.
## Длинная ось полосы идёт вдоль стены, поэтому кладку ищем за её короткими торцами.
func _ends_solid(map: Array, r: Rect2i) -> bool:
	if r.size.x >= r.size.y:
		return _line_solid(map, r.position.x - 1, r.position.y, 0, 1, r.size.y) == 1 \
			and _line_solid(map, r.position.x + r.size.x, r.position.y, 0, 1, r.size.y) == 1
	return _line_solid(map, r.position.x, r.position.y - 1, 1, 0, r.size.x) == 1 \
		and _line_solid(map, r.position.x, r.position.y + r.size.y, 1, 0, r.size.x) == 1


func _line_solid(map: Array, x: int, y: int, dx: int, dy: int, count: int) -> int:
	for i in count:
		if not _solid(map, x + dx * i, y + dy * i):
			return 0
	return 1


# =============================================================================
#  ПРЕГРАДА
# =============================================================================

## Преграда — проём, протянутый по проходу, пока по бокам стоит кладка. Запертая
## дверь перекрывает весь проход сквозь стену (в том числе если кладка в два тайла),
## но не вылезает в комнату невидимой стеной.
func _seal(map: Array, r: Rect2i, vert: bool) -> Rect2i:
	if map.is_empty():
		return r
	var fwd := _run_pass(map, r, vert, 1)
	var back := _run_pass(map, r, vert, -1)
	if fwd > 0 and fwd >= back:
		if vert:
			return Rect2i(r.position.x, r.position.y, r.size.x + fwd, r.size.y)
		return Rect2i(r.position.x, r.position.y, r.size.x, r.size.y + fwd)
	if back > 0:
		if vert:
			return Rect2i(r.position.x - back, r.position.y, r.size.x + back, r.size.y)
		return Rect2i(r.position.x, r.position.y - back, r.size.x, r.size.y + back)
	return r


## Сколько тайлов проход тянется в направлении dir, оставаясь зажатым кладкой.
## Как только по бокам появляется пол — проход вышел в комнату, дальше не тянем.
func _run_pass(map: Array, r: Rect2i, vert: bool, dir: int) -> int:
	var n := 0
	while n < MAX_RUN:
		var step := n + 1
		if vert:
			# проход идёт по X: добавляется столбец высотой с проём
			var x := (r.position.x - step) if dir < 0 else (r.position.x + r.size.x - 1 + step)
			if not _all_floor(map, Rect2i(x, r.position.y, 1, r.size.y)):
				return n
			if not _solid(map, x, r.position.y - 1) or not _solid(map, x, r.position.y + r.size.y):
				return n
		else:
			# проход идёт по Y: добавляется строка шириной с проём
			var y := (r.position.y - step) if dir < 0 else (r.position.y + r.size.y - 1 + step)
			if not _all_floor(map, Rect2i(r.position.x, y, r.size.x, 1)):
				return n
			if not _solid(map, r.position.x - 1, y) or not _solid(map, r.position.x + r.size.x, y):
				return n
		n += 1
	return n


func _score(map: Array, r: Rect2i, vert: bool, span: int, block: Rect2i) -> int:
	var declared := h if vert else w
	var aligned := 6 - mini(6, absi(span - declared))
	var near := 8 - mini(8, absi(_delta(vert, r)))
	var depth := (block.size.x - r.size.x) if vert else (block.size.y - r.size.y)
	var walled := 1 if _ends_solid(map, r) else 0
	var same := 1 if vert == vertical else 0
	return same * 60 + walled * 100 + near * 4 + aligned * 2 + mini(depth, 8)


func _delta(vert: bool, r: Rect2i) -> int:
	if vert:
		return r.position.y + r.size.y / 2 - ty
	return r.position.x + r.size.x / 2 - tx


func _all_floor(map: Array, r: Rect2i) -> bool:
	if r.size.x <= 0 or r.size.y <= 0:
		return false
	for y in range(r.position.y, r.position.y + r.size.y):
		for x in range(r.position.x, r.position.x + r.size.x):
			if _solid(map, x, y):
				return false
	return true


func _covers(outer: Rect2i, inner: Rect2i) -> bool:
	return outer.position.x <= inner.position.x and outer.position.y <= inner.position.y \
		and outer.position.x + outer.size.x >= inner.position.x + inner.size.x \
		and outer.position.y + outer.size.y >= inner.position.y + inner.size.y


func gap_px() -> Vector2:
	return Vector2(float(gap.size.x) * TILE, float(gap.size.y) * TILE)


func blocker_px() -> Vector2:
	return Vector2(float(blocker.size.x) * TILE, float(blocker.size.y) * TILE)


func kind() -> String:
	return "v" if vertical else "h"


## Ширина проёма в пикселях поперёк движения — толщина стены, в которой сидит дверь.
func leaf_thickness_px() -> float:
	return float(w if vertical else h) * TILE


## Длина одной створки в пикселях: вдоль стены, у двустворчатой — половина проёма.
func leaf_length_px() -> float:
	var long := float(h if vertical else w) * TILE
	return long * 0.5 if double else long


func describe() -> String:
	return "gap %s blocker %s (%s%s)" % [str(gap), str(blocker),
		"вертикальная" if vertical else "горизонтальная",
		", распахивается %s" % str(open_dir) if tall() else ""]
