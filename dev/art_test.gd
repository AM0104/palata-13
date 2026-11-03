extends Node
## Проверка отрисовки двери: сохраняет текстуры проёма, створки и косяков в .tmp_preview.
## Запуск: godot --path . --headless -- --art-test


func _ready() -> void:
	var cases := [
		{"name": "hospital_door", "theme": "hospital", "w": 32, "h": 32, "v": false, "d": false},
		{"name": "hospital_big", "theme": "hospital", "w": 32, "h": 64, "v": true, "d": true},
		{"name": "prison_gate", "theme": "prison", "w": 32, "h": 32, "v": false, "d": false, "bars": true},
		{"name": "church_door", "theme": "church", "w": 32, "h": 32, "v": false, "d": false},
		{"name": "cemetery_gate", "theme": "cemetery", "w": 32, "h": 32, "v": false, "d": false, "bars": true},
		{"name": "hospital_vertical", "theme": "hospital", "w": 32, "h": 64, "v": true, "d": true},
	]
	for c in cases:
		var theme := str(c["theme"])
		var w := int(c["w"])
		var h := int(c["h"])
		var v := bool(c["v"])
		var d := bool(c["d"])
		var bars := bool(c.get("bars", false))
		_save("door_%s_closed" % str(c["name"]), Doors.get_texture(theme, w, h, v, false, d, bars))
		_save("door_%s_open" % str(c["name"]), Doors.get_texture(theme, w, h, v, true, d, bars))
		_save("door_%s_leaf" % str(c["name"]), Doors.leaf_texture(theme, w, h, v, d, bars))
		_save("door_%s_frame" % str(c["name"]), Doors.frame_texture(theme, w, h, v))
	get_tree().quit()


func _save(name: String, tex: Texture2D) -> void:
	var img := tex.get_image()
	img.save_png("res://.tmp_preview/%s.png" % name)
	print("saved %s %dx%d" % [name, img.get_width(), img.get_height()])
