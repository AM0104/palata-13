extends Node
## Проверка дверей: проём стоит в стене, преграда перекрывает проход целиком, и через
## запертую дверь действительно нельзя пройти.
## Запуск: godot --path . --headless -- --door-test

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var checks := 0
var fails := 0


func _ready() -> void:
	for i in Levels.count():
		_check_floor(i)
	print("DOOR-TEST: проверок %d, ошибок %d" % [checks, fails])
	get_tree().quit()


func _ok(cond: bool, text: String) -> void:
	checks += 1
	if cond:
		print("[OK]   " + text)
	else:
		fails += 1
		print("[FAIL] " + text)


func _check_floor(index: int) -> void:
	var level := Levels.get_level(index)
	var map := Levels.build_map(level)
	var fid := str(level.get("id", "?"))
	print("--- %s" % fid)
	var list: Array = []
	for e in level.get("entities", []):
		if str(e.get("t", "")) == "door":
			list.append({"e": e, "g": DoorGeom.create(map, e)})

	for item in list:
		var g: DoorGeom = item["g"]
		var label := str(item["e"].get("label", "?"))
		print("    %-24s %s" % [label, g.describe()])
		_ok(g.valid, "%s: «%s» — геометрия определена (%s)" % [fid, label, g.note])
		_ok(_all_floor(map, g.gap), "%s: «%s» — проём целиком на полу %s" % [fid, label, str(g.gap)])
		_ok(_covers(g.blocker, g.gap), "%s: «%s» — преграда %s перекрывает проём" % [fid, label, str(g.blocker)])
		_ok(_all_floor(map, g.blocker), "%s: «%s» — преграда целиком в проходе %s" % [fid, label, str(g.blocker)])
		_ok(_inside(map, g.blocker), "%s: «%s» — преграда внутри этажа" % [fid, label])

	# Заливка с закрытыми дверями: за преграду не должно быть прохода.
	var closed := {}
	for item2 in list:
		var g2: DoorGeom = item2["g"]
		for y in range(g2.blocker.position.y, g2.blocker.position.y + g2.blocker.size.y):
			for x in range(g2.blocker.position.x, g2.blocker.position.x + g2.blocker.size.x):
				closed[Vector2i(x, y)] = true
	var sp: Dictionary = level.get("spawns", {})
	var start_arr: Array = sp.get("start", [1, 1])
	var start := Vector2i(int(start_arr[0]), int(start_arr[1]))
	var open_reach := _reach(map, start, {})
	var shut_reach := _reach(map, start, closed)

	for item3 in list:
		var g3: DoorGeom = item3["g"]
		var label3 := str(item3["e"].get("label", "?"))
		var behind := _behind(map, g3, open_reach, shut_reach)
		_ok(behind.is_empty(), "%s: «%s» — за запертой дверью не пройти %s" % [fid, label3, str(behind)])
		_ok(not open_reach.is_empty(), "%s: «%s» — карта связна при открытых дверях" % [fid, label3])


## Клетки за дверью, до которых можно дойти только через неё, но которые достижимы,
## когда дверь заперта: это и есть протечка мимо створа.
func _behind(map: Array, g: DoorGeom, open_reach: Dictionary, shut_reach: Dictionary) -> Array:
	var only_via_door := {}
	for cell in open_reach.keys():
		if not shut_reach.has(cell):
			only_via_door[cell] = true
	var leak: Array = []
	for y in range(g.gap.position.y - 1, g.gap.position.y + g.gap.size.y + 1):
		for x in range(g.gap.position.x - 1, g.gap.position.x + g.gap.size.x + 1):
			var p := Vector2i(x, y)
			if shut_reach.has(p) and only_via_door.has(p):
				leak.append(p)
	return leak


func _reach(map: Array, start: Vector2i, blocked: Dictionary) -> Dictionary:
	if blocked.has(start) or not _is_floor(map, start):
		return {}
	var seen := {start: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in DIRS:
			var n: Vector2i = cur + d
			if seen.has(n) or blocked.has(n) or not _is_floor(map, n):
				continue
			seen[n] = true
			queue.append(n)
	return seen


func _is_floor(map: Array, p: Vector2i) -> bool:
	if p.y < 0 or p.y >= map.size():
		return false
	var row := str(map[p.y])
	return p.x >= 0 and p.x < row.length() and row[p.x] == "."


func _covers(outer: Rect2i, inner: Rect2i) -> bool:
	return outer.position.x <= inner.position.x and outer.position.y <= inner.position.y \
		and outer.position.x + outer.size.x >= inner.position.x + inner.size.x \
		and outer.position.y + outer.size.y >= inner.position.y + inner.size.y


func _all_floor(map: Array, r: Rect2i) -> bool:
	for y in range(r.position.y, r.position.y + r.size.y):
		for x in range(r.position.x, r.position.x + r.size.x):
			if y < 0 or y >= map.size():
				return false
			var row := str(map[y])
			if x < 0 or x >= row.length() or row[x] != ".":
				return false
	return true


func _inside(map: Array, r: Rect2i) -> bool:
	return r.position.x >= 0 and r.position.y >= 0 and r.position.y + r.size.y <= map.size()
