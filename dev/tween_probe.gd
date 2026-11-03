extends Node
## Проверка: сколько стоит бесконечный tween, у которого удалили цель.
## Сравниваем «удалить свечение, не тронув мигание» (старое поведение) и
## «погасить мигание, потом удалить» (как сейчас в двери).
## Запуск: godot --path . --headless -- --tween-probe

const FRAMES := 180


func _ready() -> void:
	var old_ms := await _measure(false)
	var new_ms := await _measure(true)
	print("TWEEN-PROBE: со «забытым» миганием %.0f мс, с гашением %.0f мс на %d кадров" % [
		old_ms, new_ms, FRAMES])
	get_tree().quit()


func _measure(kill_first: bool) -> float:
	var light := PointLight2D.new()
	add_child(light)
	var t := create_tween()
	t.set_loops()
	t.tween_property(light, "energy", 1.5, 0.3)
	t.tween_property(light, "energy", 0.5, 0.3)
	await get_tree().process_frame
	if kill_first:
		t.kill()
	light.queue_free()
	var t0 := Time.get_ticks_usec()
	for i in FRAMES:
		await get_tree().process_frame
	return float(Time.get_ticks_usec() - t0) / 1000.0
