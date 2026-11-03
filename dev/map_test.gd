extends Node
## Проверка связности этажей: ловим софтлоки в цепочках «ключ → дверь».
## Для каждого этажа решаем задачу «замок и ключ»: от старта собираем всё доступное,
## открываем двери подходящими предметами и флагами и проверяем, что выход достижим.
## Запуск: godot --path . --headless -- --map-test

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var checks := 0
var fails := 0


func _ready() -> void:
	for i in Levels.count():
		_check_floor(i)
	print("MAP-TEST: проверок %d, ошибок %d" % [checks, fails])
	get_tree().quit()


func _check_floor(index: int) -> void:
	var level := Levels.get_level(index)
	var map := Levels.build_map(level)
	var fid := str(level.get("id", "?"))
	var ents: Array = level.get("entities", [])
	var sp: Dictionary = level.get("spawns", {})
	var start_arr: Array = sp.get("start", [1, 1])
	var start := Vector2i(int(start_arr[0]), int(start_arr[1]))

	_ok(_walkable(map, start), "%s: точка старта на полу" % fid)

	var items := {}
	var flags := {}
	var opened := {}
	var dug := 0
	var lit := 0
	var reach := {}
	var route: Array = [start]
	var pointless: Array = []

	for round_i in 80:
		reach = _flood(map, start, ents, opened)
		var changed := false

		for e in ents:
			var t := _tile_of(e)
			if not reach.has(t):
				continue
			var kind := str(e.get("t", ""))
			var key := "obj:%d:%d" % [t.x, t.y]
			if opened.has(key):
				continue
			match kind:
				"pickup":
					items[str(e.get("item", ""))] = true
					opened[key] = true
					changed = true
				"note", "lore":
					var f := str(e.get("flag", ""))
					if f != "" and not flags.has(f):
						flags[f] = true
						changed = true
					opened[key] = true
				"keypad":
					if _need_ok(e, items, flags):
						var rw := str(e.get("reward", ""))
						if rw != "" and not items.has(rw):
							items[rw] = true
							changed = true
						opened[key] = true
				"npc":
					var met := false
					for eff in _npc_effects(e):
						var tag := str(eff[0]) + ":" + str(eff[1])
						if opened.has(tag):
							continue
						opened[tag] = true
						met = true
						if str(eff[0]) == "item":
							items[str(eff[1])] = true
						else:
							flags[str(eff[1])] = true
						changed = true
					if met:
						route.append(t)
				"grave":
					if items.has("shovel") and int(e.get("order", 0)) == dug + 1:
						dug += 1
						opened[key] = true
						if dug == 2:
							items["key_crypt"] = true
						if dug >= 3:
							items["grave_key"] = true
						changed = true
				"candle":
					if int(e.get("order", 0)) == lit + 1:
						lit += 1
						opened[key] = true
						if lit == 3:
							flags["b2_third_lit"] = true
						if lit >= 4:
							flags["b2_candles_lit"] = true
						changed = true
			if opened.has(key):
				route.append(t)

		for e in ents:
			if str(e.get("t", "")) != "door":
				continue
			var t := _tile_of(e)
			var key := "door:%d:%d" % [t.x, t.y]
			if opened.has(key):
				continue
			var rect := _door_rect(e)
			if not _rect_touchable(reach, rect):
				continue
			if not _need_ok(e, items, flags):
				continue
			var before := reach.size()
			opened[key] = true
			var after := _flood(map, start, ents, opened)
			if after.size() == before:
				# дверь ничего не отгораживает: за ней можно было пройти и так
				pointless.append(str(e.get("label", key)))
			route.append(t)
			changed = true

		if not changed:
			break

	_ok(pointless.is_empty(), "%s: каждая запертая дверь что-то отгораживает (пустых: %d) %s"
		% [fid, pointless.size(), str(pointless)])

	# --- объекты не должны стоять в стене
	var stuck := 0
	for e in ents:
		var kind := str(e.get("t", ""))
		if kind in ["enemy", "door"]:
			continue
		if not reach.has(_tile_of(e)):
			stuck += 1
			print("    [объект вне доступа] %s %s в %s" % [fid, kind, str(_tile_of(e))])
	_ok(stuck == 0, "%s: все объекты достижимы (вне доступа: %d)" % [fid, stuck])

	# --- выход достижим с нужными ключами (на последнем этаже — алтарь)
	var has_exit := false
	var goal_ok := false
	for e in ents:
		var goal_kind := str(e.get("t", ""))
		if goal_kind == "exit":
			has_exit = true
			if reach.has(_tile_of(e)) and _need_ok(e, items, flags):
				goal_ok = true
		elif goal_kind == "altar":
			if reach.has(_tile_of(e)) and _need_ok(e, items, flags):
				goal_ok = true
	if has_exit:
		_ok(goal_ok, "%s: выход достижим (предметов %d, флагов %d)"
			% [fid, items.size(), flags.size()])
	else:
		_ok(goal_ok, "%s: алтарь достижим и открыт (предметов %d, флагов %d)"
			% [fid, items.size(), flags.size()])

	# --- сколько чистой ходьбы требует цепочка (нижняя оценка длины этажа)
	var goal_tile := Vector2i(-1, -1)
	for e in ents:
		if str(e.get("t", "")) in ["exit", "altar"] and reach.has(_tile_of(e)):
			goal_tile = _tile_of(e)
			break
	var tiles := 0
	var prev: Vector2i = start
	for p in route:
		tiles += _bfs_dist(map, prev, p)
		prev = p
	if goal_tile != Vector2i(-1, -1):
		tiles += _bfs_dist(map, prev, goal_tile)
	var walk_sec := float(tiles) * Levels.TILE / 112.0 + float(route.size()) * 3.0
	print("    %s: маршрут %d тайлов, ~%.0f с ходьбы и взаимодействий (%.1f мин) — без боёв и поиска"
		% [fid, tiles, walk_sec, walk_sec / 60.0])
	_ok(walk_sec >= 40.0, "%s: одна только цепочка — не меньше 40 секунд (%.0f с)" % [fid, walk_sec])


# --- карта ----------------------------------------------------------------

## Кратчайший путь по полу между клетками (двери считаем открытыми) — в тайлах.
func _bfs_dist(map: Array, a: Vector2i, b: Vector2i) -> int:
	if a == b:
		return 0
	var dist := {a: 0}
	var queue: Array = [a]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in DIRS:
			var n: Vector2i = cur + d
			if dist.has(n) or not _walkable(map, n):
				continue
			dist[n] = int(dist[cur]) + 1
			if n == b:
				return int(dist[n])
			queue.append(n)
	return 0


func _walkable(map: Array, p: Vector2i) -> bool:
	if p.y < 0 or p.y >= map.size():
		return false
	var row := str(map[p.y])
	if p.x < 0 or p.x >= row.length():
		return false
	return row[p.x] == "."


func _tile_of(e: Dictionary) -> Vector2i:
	return Vector2i(int(floor(float(e.get("x", 0)))), int(floor(float(e.get("y", 0)))))


func _door_rect(e: Dictionary) -> Array:
	var t := _tile_of(e)
	var blk: Array = e.get("block", [1, 1])
	var bw := int(blk[0]) if blk.size() > 0 else 1
	var bh := int(blk[1]) if blk.size() > 1 else 1
	var x0 := int(round(float(e.get("x", 0)) - bw / 2.0))
	var y0 := int(round(float(e.get("y", 0)) - bh / 2.0))
	return [x0, y0, bw, bh]


func _rect_touchable(reach: Dictionary, rect: Array) -> bool:
	var x0: int = rect[0]
	var y0: int = rect[1]
	var w: int = rect[2]
	var h: int = rect[3]
	for x in range(x0 - 1, x0 + w + 1):
		for y in range(y0 - 1, y0 + h + 1):
			if x >= x0 and x < x0 + w and y >= y0 and y < y0 + h:
				continue
			if reach.has(Vector2i(x, y)):
				return true
	return false


## Проход по полу от старта; закрытые двери перекрывают свои клетки.
func _flood(map: Array, start: Vector2i, ents: Array, opened: Dictionary) -> Dictionary:
	var blocked := {}
	for e in ents:
		if str(e.get("t", "")) != "door":
			continue
		var t := _tile_of(e)
		if opened.has("door:%d:%d" % [t.x, t.y]):
			continue
		var rect := _door_rect(e)
		for x in range(int(rect[0]), int(rect[0]) + int(rect[2])):
			for y in range(int(rect[1]), int(rect[1]) + int(rect[3])):
				blocked[Vector2i(x, y)] = true

	var seen := {}
	if not _walkable(map, start) or blocked.has(start):
		return seen
	seen[start] = true
	var queue: Array = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_back()
		for d in DIRS:
			var n: Vector2i = cur + d
			if seen.has(n) or blocked.has(n):
				continue
			if not _walkable(map, n):
				continue
			seen[n] = true
			queue.append(n)
	return seen


# --- условия и эффекты -----------------------------------------------------

func _need_ok(e: Dictionary, items: Dictionary, flags: Dictionary) -> bool:
	var need_item := str(e.get("requires_item", ""))
	if need_item != "" and not items.has(need_item):
		return false
	var need_flag := str(e.get("requires_flag", ""))
	if need_flag != "" and not flags.has(need_flag):
		return false
	var multi: Variant = e.get("requires_flags", [])
	if multi is Array:
		for f in (multi as Array):
			if not flags.has(str(f)):
				return false
	return true


## Что даёт разговор с NPC: все варианты диалогов, чьи условия выполнимы.
func _npc_effects(e: Dictionary) -> Array:
	var out: Array = []
	var sources: Array = []
	sources.append([str(e.get("dialog", "")), "", ""])
	if str(e.get("alt_dialog", "")) != "":
		sources.append([str(e.get("alt_dialog", "")), str(e.get("alt_flag", "")), "flag"])
	var fd: Dictionary = e.get("flag_dialog", {})
	for k in fd.keys():
		sources.append([str(fd[k]), str(k), "flag"])
	var idm: Dictionary = e.get("item_dialog", {})
	for k in idm.keys():
		sources.append([str(idm[k]), str(k), "item"])
	for s in sources:
		var did := str(s[0])
		if did == "":
			continue
		out.append_array(_dialog_effects(did))
	return out


func _dialog_effects(id: String) -> Array:
	var out: Array = []
	for step in Dialogs.get_dialog(id):
		if not (step is Dictionary):
			continue
		var d: Dictionary = step
		if d.has("do") and d["do"] is Dictionary:
			out.append_array(_do_effects(d["do"]))
		if d.has("choice") and d["choice"] is Array:
			for c in (d["choice"] as Array):
				if c is Dictionary:
					out.append_array(_do_effects(c))
	return out


func _do_effects(d: Dictionary) -> Array:
	var out: Array = []
	if d.has("item"):
		out.append(["item", str(d["item"])])
	if d.has("flag"):
		out.append(["flag", str(d["flag"])])
	if d.has("flag2"):
		out.append(["flag", str(d["flag2"])])
	return out


# --- отчёт ----------------------------------------------------------------

func _ok(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		fails += 1
	print("%s %s" % ["[OK]  " if condition else "[FAIL]", message])

