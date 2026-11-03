extends Node
## Полные ASCII-карты всех горизонтов.
## Запуск: godot --path . --headless -- --map-dump

func _ready() -> void:
	for idx in Levels.count():
		var level := Levels.get_level(idx)
		var map := Levels.build_map(level)
		print("=== %s %s ===" % [str(level.get("id", "?")), str(level.get("size", []))])
		for y in map.size():
			print("%2d |%s|" % [y, str(map[y])])
	get_tree().quit()
