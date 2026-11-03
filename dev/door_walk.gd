extends Node
## Физическая проверка дверей: игрок действительно проходит сквозь открытую дверь
## и действительно упирается в закрытую.
## Запуск: godot --path . --headless -- --door-walk

const APPROACH := 56.0   ## с какой стороны и как далеко игрок начинает
const WALK_FRAMES := 180 ## сколько кадров физики идёт
const CROSS := 24.0      ## на сколько пикселей за центр проёма нужно уйти

var main: Node
var checks := 0
var fails := 0


func _ready() -> void:
	main = get_parent()
	await _frames(4)
	main._on_new_game()
	await _frames(6)
	for f in ["B5", "B4", "B3", "B2"]:
		Game.set_flag("intro:%s" % f)
	for idx in [0, 1, 2, 3]:
		await _floor(idx)
	print("DOOR-WALK: проверок %d, ошибок %d" % [checks, fails])
	_release()
	get_tree().quit()


func _ok(cond: bool, text: String) -> void:
	checks += 1
	if cond:
		print("[OK]   " + text)
	else:
		fails += 1
		print("[FAIL] " + text)


func _floor(idx: int) -> void:
	main.load_floor(idx)
	await _frames(20)
	main.ui.close_modals()
	await _frames(4)
	var fid := str(main.world.level.get("id", "?"))
	var doors: Array = []
	for it in main.world.get_tree().get_nodes_in_group("interactables"):
		if it is Interactable and it.kind == "door":
			doors.append(it)
	for door in doors:
		await _probe(fid, door)


## Куда ведёт проход: сторона, в которую протянута преграда.
func _dir(door: Interactable) -> Vector2:
	var g: DoorGeom = door._geom
	if g.vertical:
		return Vector2.LEFT if g.blocker.position.x < g.gap.position.x else Vector2.RIGHT
	return Vector2.UP if g.blocker.position.y + g.blocker.size.y <= g.gap.position.y + g.gap.size.y else Vector2.DOWN


func _probe(fid: String, door: Interactable) -> void:
	var label := "%s «%s»" % [fid, str(door.data.get("label", "?"))]
	var dir := _dir(door)
	var center: Vector2 = door._geom.center
	var player: Player = main.world.player
	player.input_enabled = true
	player.set_physics_process(true)
	# враги могут отбросить игрока и сломать замер — на время проверки он неуязвим
	player._invuln = 999.0

	# --- закрытая дверь не пускает
	door.set_door_open(false)
	await _frames(6)
	print("    %s blocking=%s disabled=%s open=%s shape=%s" % [label, str(door.is_blocking()),
		str(door._blocker_shape.disabled), str(door.is_open()), str(door._blocker_shape.global_position)])
	player.teleport(center - dir * APPROACH)
	await _frames(3)
	await _walk(dir)
	var mov_closed := (player.global_position - center).dot(dir)
	_ok(mov_closed < CROSS, "%s: закрытая дверь не пропускает (%.0f px)" % [label, mov_closed])

	# --- открытая дверь пропускает
	door.set_door_open(true)
	await _frames(20)
	player.teleport(center - dir * APPROACH)
	await _frames(3)
	await _walk(dir)
	var mov_open := (player.global_position - center).dot(dir)
	_ok(mov_open > CROSS, "%s: открытая дверь пропускает (%.0f px)" % [label, mov_open])

	_release()
	door.set_door_open(false)
	player.set_physics_process(false)
	await _frames(6)


func _walk(dir: Vector2) -> void:
	_press(dir)
	for i in WALK_FRAMES:
		await get_tree().physics_frame
	_release()


func _press(dir: Vector2) -> void:
	if dir.x < -0.5:
		Input.action_press("move_left")
	elif dir.x > 0.5:
		Input.action_press("move_right")
	if dir.y < -0.5:
		Input.action_press("move_up")
	elif dir.y > 0.5:
		Input.action_press("move_down")


func _release() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		if Input.is_action_pressed(a):
			Input.action_release(a)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
