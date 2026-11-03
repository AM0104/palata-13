extends Node
## Замер отклика на взаимодействия: сколько миллисекунд занимает сам вызов interact()
## и сколько ждёт следующий кадр. Ловит подвисания на дверях, записках, сундуках, НПС.
## Запуск: godot --path . --headless -- --interact-test

const FRAMES := 20
const HITCH_MS := 60.0

var main: Node
var worst_call := 0.0
var worst_call_what := ""
var worst_frame := 0.0
var worst_frame_what := ""
var errors := 0
var _mark := ""
var _last_frame_us := 0


func _ready() -> void:
	main = get_parent()
	await _frames(4)
	main._on_new_game()
	await _frames(8)
	for f in ["B5", "B4", "B3", "B2"]:
		Game.set_flag("intro:%s" % f)
	_last_frame_us = Time.get_ticks_usec()
	for idx in [0, 1, 2, 3]:
		await _floor(idx)
	print("INTERACT-TEST: худший вызов %.0f мс (%s), худший кадр %.0f мс (%s), ошибок %d" % [
		worst_call, worst_call_what, worst_frame, worst_frame_what, errors])
	get_tree().quit()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var ms := float(now - _last_frame_us) / 1000.0
	_last_frame_us = now
	if ms > worst_frame:
		worst_frame = ms
		worst_frame_what = _mark


func _floor(idx: int) -> void:
	main.load_floor(idx)
	await _frames(30)
	main.ui.close_modals()
	await _frames(4)
	var fid := str(main.world.level.get("id", "?"))
	var player: Player = main.world.player
	var items: Array = []
	for it in main.world.get_tree().get_nodes_in_group("interactables"):
		if it is Interactable:
			items.append(it)
	print("--- %s: объектов %d" % [fid, items.size()])
	for it in items:
		var label := "%s «%s»" % [fid, str(it.data.get("label", it.kind))]
		# дверям выдаём ключи, чтобы проверить именно открытие, а не отказ
		if it.kind == "door":
			var need := str(it.data.get("requires_item", ""))
			if need != "":
				Game.add_item(need)
			var flag := str(it.data.get("requires_flag", ""))
			if flag != "":
				Game.set_flag(flag)
			if it.is_open():
				it.set_door_open(false)
				await _frames(8)
		# подходим вплотную: игрок должен оказаться в зоне взаимодействия
		player.global_position = it.global_position + Vector2(0, 22)
		await _frames(4)
		_mark = "вызов " + label
		var t0 := Time.get_ticks_usec()
		it.interact(player)
		var call_ms := float(Time.get_ticks_usec() - t0) / 1000.0
		if it.kind == "door":
			print("    дверь %-24s открылась=%s, %.0f мс" % [str(it.data.get("label", "?")),
				str(it.is_open()), call_ms])
		if call_ms > worst_call:
			worst_call = call_ms
			worst_call_what = label
		if call_ms > HITCH_MS:
			print("    ДОЛГО %.0f мс: %s" % [call_ms, label])
		_mark = "кадр после " + label
		await _frames(FRAMES)
		main.ui.close_modals()
		await _frames(4)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
