extends Node
## Проверка входа в 3D-режим из главного меню: жмём пункт «ОСОБНЯК · 3D»
## и смотрим, что проект переключился на сцену House3D.
## Запуск: godot --headless --path . -- --test-menu3d

func _ready() -> void:
	var main := get_parent()
	await get_tree().process_frame
	var links: Array = main.ui.menu.house_requested.get_connections()
	print("MENU3D menu links=%d ui_links=%d" % [
		links.size(), main.ui.house_requested.get_connections().size()])
	main.ui.menu.house_requested.emit()
