extends Node
## Автопроверка 3D-режима: записки, печати, пробуждение Хозяйки, выход и смерть.
## Запуск: godot --headless --path . res://scenes/House3D.tscn -- --playtest-3d
##         godot --headless --path . res://scenes/House3D.tscn -- --playtest-3d --death

var game: Node
var fails := 0
var death_mode := false
var ghost_mode := false


func setup(g: Node) -> void:
	game = g
	process_mode = Node.PROCESS_MODE_ALWAYS
	death_mode = OS.get_cmdline_user_args().has("--death") or OS.get_cmdline_args().has("--death")
	ghost_mode = OS.get_cmdline_user_args().has("--ghost") or OS.get_cmdline_args().has("--ghost")
	_run()


func _check(ok: bool, what: String) -> void:
	if ok:
		print("PLAYTEST3D OK   %s" % what)
	else:
		fails += 1
		print("PLAYTEST3D FAIL %s" % what)


func _run() -> void:
	await _wait(0.4)
	_check(game._cells.size() > 100, "walker cells built (%d)" % game._cells.size())
	_check(game.player != null, "player spawned")
	_check(game.ghost != null, "ghost spawned")

	await _test_intro_mouse()

	await _wait(1.2)
	_check(game.player.is_on_floor(), "player stands on the floor")
	var py: float = game.player.global_position.y
	_check(py > 0.7 and py < 1.2, "spawn height sane (%.2f)" % py)

	var seals: Array = []
	var notes: Array = []
	var batteries: Array = []
	for n in get_tree().get_nodes_in_group("house_interactable"):
		match n.kind:
			"seal":
				seals.append(n)
			"note":
				notes.append(n)
			"battery":
				batteries.append(n)
	_check(seals.size() == 3, "three seals in world (%d)" % seals.size())
	_check(notes.size() == 5, "five notes in world (%d)" % notes.size())
	_check(batteries.size() == 2, "two batteries in world (%d)" % batteries.size())

	await _test_walk()
	await _test_mouse()
	await _test_settings()

	if death_mode:
		await _test_death()
	elif ghost_mode:
		await _test_ghost()
	else:
		await _test_note(notes[0])
		await _test_battery(batteries[0])
		await _test_exit_locked()
		await _test_seals(seals)
		await _test_win()

	print("PLAYTEST3D DONE fails=%d" % fails)
	await _wait(1.5)
	get_tree().quit()


func _test_walk() -> void:
	var spawn: Vector3 = game._snap(Vector2(0.0, 5.9))
	game.player.teleport_to(Vector3(spawn.x, spawn.y + 0.92, spawn.z))
	game.player.rotation.y = 0.0
	await _wait(0.2)
	var start: Vector3 = game.player.global_position
	Input.action_press("move_up")
	await _wait(1.4)
	Input.action_release("move_up")
	await _wait(0.2)
	var moved := start.distance_to(game.player.global_position)
	_check(moved > 1.0, "player walks forward (%.2f m)" % moved)

	# завал: идём в сторону выхода, сквозь доски пройти нельзя
	game.player.teleport_to(Vector3(spawn.x, spawn.y + 0.92, 5.5))
	game.player.rotation.y = PI
	await _wait(0.2)
	Input.action_press("move_up")
	await _wait(1.6)
	Input.action_release("move_up")
	await _wait(0.1)
	var z: float = game.player.global_position.z
	_check(z < 7.2, "barricade blocks the exit (z=%.2f)" % z)
	game.player.teleport_to(Vector3(spawn.x, spawn.y + 0.92, spawn.z))


func _test_intro_mouse() -> void:
	_check(game.hud._intro.visible, "intro overlay exists at start")
	# Ни один элемент интро не должен перехватывать мышь.
	var blockers := 0
	for c in game.hud._intro.get_children():
		if c is Control and (c as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
			blockers += 1
	_check(blockers == 0, "intro overlay does not block mouse input")
	game.hud._skip_intro()
	await _wait(0.05)


func _test_mouse() -> void:
	# мышь должна вращать камеру даже без захвата курсора (встроенный режим редактора)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var yaw0: float = game.player.rotation.y
	var pitch0: float = game.player.camera.rotation.x
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(120, 40)
	game.player._unhandled_input(ev)
	await _wait(0.05)
	_check(absf(game.player.rotation.y - yaw0) > 0.01, "mouse turns the camera without capture")
	_check(absf(game.player.camera.rotation.x - pitch0) > 0.005, "mouse tilts the camera")
	game.player.rotation.y = 0.0
	game.player.camera.rotation.x = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _test_settings() -> void:
	var before: float = Settings.mouse_sensitivity
	Settings.set_mouse_sensitivity(1.7)
	_check(absf(Settings.mouse_sensitivity - 1.7) < 0.01, "mouse sensitivity is stored")
	Settings.set_mouse_sensitivity(before)

	Settings.set_shadows(false)
	await _wait(0.05)
	_check(not game._moon.shadow_enabled, "shadows toggle off works")
	Settings.set_shadows(true)
	await _wait(0.05)
	_check(game._moon.shadow_enabled, "shadows toggle on works")

	Settings.set_fog(false)
	await _wait(0.05)
	_check(not game._env.fog_enabled, "fog toggle off works")
	Settings.set_fog(true)


func _test_note(note: Node) -> void:
	game._on_interact(note)
	await _wait(0.1)
	_check(get_tree().paused, "note pauses the game")
	_check(game.hud.note_open(), "note panel is open")
	game.hud.close_note()
	await _wait(0.1)
	_check(not get_tree().paused, "closing note unpauses")
	_check(note.done, "note marked read")


func _test_battery(bat: Node) -> void:
	var before: float = game.player.battery
	game._on_interact(bat)
	await _wait(0.1)
	_check(game.player.battery > before, "battery charges the flashlight")
	_check(bat.done, "battery consumed")


func _test_exit_locked() -> void:
	game._try_exit()
	await _wait(0.05)
	_check(not game.exit_open, "exit stays locked without seals")
	_check(game._exit_blocker != null, "exit barricade present")


func _test_seals(seals: Array) -> void:
	for s in seals:
		game._on_interact(s)
		await _wait(0.05)
	_check(game.seals_taken == 3, "all seals collected")
	_check(game.ghost.active, "ghost awakened")
	_check(game.exit_open, "exit unlocked after three seals")
	await _wait(0.2)
	_check(game._exit_blocker == null, "barricade collision removed")
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(0, 1.0, 5.5), Vector3(0, 1.0, 9.5))
	q.exclude = [game.player.get_rid()]
	var hit := space.intersect_ray(q)
	_check(hit.is_empty(), "doorway is clear after unlock")


func _test_win() -> void:
	var spawn: Vector3 = game._snap(Vector2(0.0, 5.5))
	game.player.teleport_to(Vector3(spawn.x, spawn.y + 0.92, 5.5))
	game.player.rotation.y = PI
	await _wait(0.2)
	Input.action_press("move_up")
	await _wait(2.4)
	Input.action_release("move_up")
	await _wait(0.2)
	_check(game.finished, "win triggers when leaving")
	_check(game.hud._win_panel.visible, "win screen shown")


func _test_death() -> void:
	game.hearts = 1
	game._on_ghost_touched()
	await _wait(0.1)
	_check(game.finished, "death when hearts run out")
	_check(game.hud._death_panel.visible, "death screen shown")


func _test_ghost() -> void:
	game.ghost.awaken()
	game.ghost.start_hunt_now()
	var forward: Vector3 = -game.player.camera.global_transform.basis.z
	game.ghost.global_position = game.player.global_position + forward * 0.9
	await _wait(0.4)
	_check(game.hearts == 2, "ghost takes exactly one heart (%d)" % game.hearts)
	var away: float = game.ghost.global_position.distance_to(game.player.global_position)
	_check(away > 5.0, "ghost vanishes far away (%.1f m)" % away)
	_check(not game.finished, "one hit does not kill")


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
