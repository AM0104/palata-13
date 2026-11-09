extends Node
## Проверка полного круга: 3D-сцена → «В главное меню» → меню загрузилось.
## Узел живёт в корне дерева, поэтому переживает смену сцены.
## Запуск: godot --headless --path . res://scenes/House3D.tscn -- --roundtrip

var game: Node


func setup(g: Node) -> void:
	game = g
	call_deferred("_start")


func _start() -> void:
	await _wait(0.6)
	print("ROUNDTRIP 3d_scene=%s" % str(get_tree().current_scene.name))
	game._to_menu()
	await _wait(2.0)
	var scene: Node = get_tree().current_scene
	print("ROUNDTRIP back_scene=%s" % str(scene.name if scene != null else "null"))
	var ok := scene != null and scene.has_method("dev_state") and scene.get("ui") != null
	print("ROUNDTRIP menu_ok=%s paused=%s" % [str(ok), str(get_tree().paused)])
	print("ROUNDTRIP DONE")
	await _wait(0.4)
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
