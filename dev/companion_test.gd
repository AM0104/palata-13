extends Node
## Автотест поведения Зака: рубит только врагов рядом с Рэйчел, не бегает по карте
## за врагами и никогда не задевает саму Рэйчел.
## Запуск: godot --path . --headless -- --companion-test

var main: Node
var world: World
var checks := 0
var fails := 0
var swings := 0
var _dummy: Player


func _ready() -> void:
	main = get_parent()
	get_tree().create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		print("COMPANION-TEST: ТАЙМАУТ — проверок %d, ошибок %d" % [checks, fails])
		get_tree().quit())
	await _wait(0.6)
	await _run()
	print("COMPANION-TEST: проверок %d, ошибок %d" % [checks, fails])
	get_tree().quit()


func _run() -> void:
	main._on_new_game()
	await _wait(0.6)
	main.ui.close_modals()
	await _wait(0.3)

	world = main.world
	var rachel: Player = world.player
	var zach: Companion = world.companion
	_ok(rachel != null and zach != null, "Мир готов: Рэйчел и Зак на месте")
	if rachel == null or zach == null:
		return

	# врагам подсовываем «пустого» игрока, чтобы они не били Рэйчел во время теста
	_dummy = Player.new()
	_dummy.input_enabled = false
	_dummy.global_position = Vector2(-4000, -4000)
	world.ysort.add_child(_dummy)
	_clear_enemies()
	await _wait(0.2)

	# --- 1. враг рядом с Рэйчел: Зак бьёт сам, без нажатий
	zach.attacked.connect(func() -> void: swings += 1)
	var near := _spawn_still_enemy(rachel.global_position + Vector2(34, 0))
	await _wait(0.1)
	_ok(zach.threat == near, "Угроза — враг, подошедший к Рэйчел")
	var near_hp := near.hp
	var hp_before := Game.hp
	var max_dist := 0.0
	for i in 40:
		await _wait(0.05)
		max_dist = maxf(max_dist, zach.global_position.distance_to(rachel.global_position))
	_ok(swings >= 2, "Зак рубит подошедшего врага, а не один раз (ударов %d)" % swings)
	_ok(is_instance_valid(near) and near.hp < near_hp,
		"Зак сам ударил врага рядом с Рэйчел (hp %d → %d)" % [near_hp, near.hp if is_instance_valid(near) else 0])
	_ok(Game.hp == hp_before, "Коса Зака не задела Рэйчел (hp %d)" % Game.hp)
	_ok(max_dist <= Companion.LEASH + 12.0,
		"В бою Зак не отходил от Рэйчел (макс. %.1f px)" % max_dist)

	# --- 2. дальний враг: Зак его не ищет и не идёт к нему
	_clear_enemies()
	var far := _spawn_still_enemy(rachel.global_position + Vector2(380, 0))
	var far_hp := far.hp
	max_dist = 0.0
	var min_to_far := 1.0e9
	for i in 40:
		await _wait(0.05)
		max_dist = maxf(max_dist, zach.global_position.distance_to(rachel.global_position))
		min_to_far = minf(min_to_far, zach.global_position.distance_to(far.global_position))
	_ok(zach.threat == null, "Дальний враг не считается угрозой")
	_ok(is_instance_valid(far) and far.hp == far_hp, "Дальнего врага Зак не трогает (hp %d)" % far_hp)
	_ok(min_to_far > 250.0, "Зак не пошёл к дальнему врагу (минимум %.1f px)" % min_to_far)
	_ok(max_dist <= Companion.LEASH + 12.0,
		"Без угрозы Зак держится Рэйчел (макс. %.1f px)" % max_dist)

	# --- 3. Рэйчел уходит: Зак идёт за ней, а не остаётся у врага
	var spot := _open_spot(rachel.global_position, 190.0)
	_ok(spot.distance_to(rachel.global_position) > 100.0,
		"Для шага найден свободный коридор (%.0f px)" % spot.distance_to(rachel.global_position))
	rachel.teleport(spot)
	await _wait(2.6)
	_ok(zach.global_position.distance_to(rachel.global_position) < 120.0,
		"Зак догнал Рэйчел, а не остался у врага (%.1f px)" % zach.global_position.distance_to(rachel.global_position))
	_ok(zach.global_position.distance_to(far.global_position) > 150.0,
		"Зак не вернулся к дальнему врагу (%.1f px)" % zach.global_position.distance_to(far.global_position))
	_ok(is_instance_valid(far) and far.hp == far_hp, "Дальний враг так и остался целым (hp %d)" % far_hp)


# --- вспомогательное -------------------------------------------------------

## Неподвижный враг, который не aggro-ится на Рэйчел и не бьёт её.
func _spawn_still_enemy(pos: Vector2) -> Enemy:
	var e := world._spawn_enemy("crawler", pos)
	e.target = _dummy
	e.speed = 0.0
	e.aggro_range = 0.0
	e.hp = 20
	return e


func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != null and is_instance_valid(e):
			e.queue_free()


## Точка на расстоянии dist, до которой от origin нет стен (Зак идёт по прямой).
func _open_spot(origin: Vector2, dist: float) -> Vector2:
	for i in 32:
		var p := origin + Vector2.from_angle(TAU * float(i) / 32.0) * dist
		if _path_clear(origin, p):
			return p
	return origin


func _path_clear(from: Vector2, to: Vector2) -> bool:
	var steps := maxi(1, int(from.distance_to(to) / 8.0))
	for i in steps + 1:
		var p := from.lerp(to, float(i) / float(steps))
		var tx := int(floor(p.x / float(World.TILE)))
		var ty := int(floor(p.y / float(World.TILE)))
		if ty < 0 or ty >= world.map.size():
			return false
		var row := str(world.map[ty])
		if tx < 1 or tx >= row.length() - 1 or row[tx] == "#":
			return false
	return true


func _ok(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		fails += 1
	print("%s %s" % ["[OK]  " if condition else "[FAIL]", message])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
