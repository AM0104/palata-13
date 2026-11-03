extends Node
## Диагностика дверей: печатает окрестность карты вокруг каждой двери.
## Запуск: godot --path . --headless -- --door-scan

const R := 6


func _ready() -> void:
	for i in Levels.count():
		var level := Levels.get_level(i)
		var map := Levels.build_map(level)
		print("=== %s" % str(level.get("id", "?")))
		for e in level.get("entities", []):
			if str(e.get("t", "")) != "door":
				continue
			_dump(map, e)
	get_tree().quit()


func _dump(map: Array, e: Dictionary) -> void:
	var tx := int(floor(float(e.get("x", 0))))
	var ty := int(floor(float(e.get("y", 0))))
	print("--- %s  at (%d,%d) block %s" % [str(e.get("label", "?")), tx, ty, str(e.get("block", []))])
	var head := "      "
	for x in range(tx - R, tx + R + 1):
		head += str(x % 10)
	print(head)
	for y in range(ty - R, ty + R + 1):
		var line := "%4d |" % y
		for x in range(tx - R, tx + R + 1):
			var ch := "#"
			if y >= 0 and y < map.size():
				var row := str(map[y])
				if x >= 0 and x < row.length():
					ch = row[x]
			if x == tx and y == ty:
				line += "D" if ch == "." else "X"
			else:
				line += ch
		print(line + "|")
