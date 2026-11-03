class_name World
extends Node2D
## Собирает этаж из данных Levels.gd: пол, стены, мебель, свет, объекты, врагов.
## Обрабатывает сюжетные действия, приходящие из диалогов.

signal dialog_requested(id: String)
signal note_requested(title: String, body: String)
signal code_requested(it: Interactable)
signal floor_exit(target: int)
signal ending_requested(ending: String)

const TILE := 32
const CAMERA_MARGIN := 24.0     ## поля вокруг этажа, чтобы стены не липли к краю экрана
const CAMERA_MAX_ZOOM := 1.2
const CAMERA_MIN_ZOOM := 0.8

var level: Dictionary = {}
var floor_index := 0
var map: Array = []
var player: Player
var companion: Companion = null
var doctor: Enemy = null
var ysort: Node2D
var world_seed := 7

var _flicker: Array = []
var _shake := 0.0
var _time := 0.0
var _doctor_timer := 0.0
var _intro_shown := false
var _entity_nodes: Array = []
var _gas_zones: Array = []


func build(index: int) -> void:
	floor_index = index
	level = Levels.get_level(index).duplicate(true)
	level["map"] = Levels.build_map(level)
	map = level["map"]
	world_seed = int(level.get("seed", 7))
	var theme := str(level.get("theme", "hospital"))

	var bg := Sprite2D.new()
	bg.texture = Tex.level_texture(level)
	bg.centered = false
	bg.z_index = -100
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(bg)

	var cm := CanvasModulate.new()
	cm.color = _ambient_color(theme)
	add_child(cm)

	_build_walls()

	ysort = Node2D.new()
	ysort.y_sort_enabled = true
	add_child(ysort)

	_build_props(theme)
	_build_lights()

	player = Player.new()
	player.global_position = _spawn_pos("start")
	ysort.add_child(player)
	player.world = self
	player.damaged.connect(_on_player_hurt)
	player.prompt_changed.connect(_on_prompt)

	_setup_camera()

	_build_entities()

	Game.begin_shift()
	Audio.start_ambient(str(level.get("ambient", "hospital")))
	if not Game.flag("intro:%s" % str(level.get("id", "?"))):
		Game.set_flag("intro:%s" % str(level.get("id", "?")))
		call_deferred("_show_intro")


func _show_intro() -> void:
	var intro := str(level.get("intro", ""))
	if intro != "":
		show_dialog(intro)


func _process(delta: float) -> void:
	_time += delta
	for entry in _flicker:
		var light: PointLight2D = entry[0]
		var base: float = entry[1]
		var phase: float = entry[2]
		var n := sin(_time * 11.0 + phase) * 0.5 + sin(_time * 23.0 + phase * 2.0) * 0.25 + sin(_time * 3.3 + phase) * 0.25
		light.energy = maxf(0.05, base * (0.82 + 0.18 * n))
	if _shake > 0.01:
		_shake = lerpf(_shake, 0.0, clampf(delta * 6.0, 0.0, 1.0))
		if player != null and player.camera != null:
			player.camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	elif player != null and player.camera != null and player.camera.offset != Vector2.ZERO:
		player.camera.offset = Vector2.ZERO

	if _doctor_timer > 0.0:
		_doctor_timer -= delta
		if _doctor_timer <= 0.0:
			dismiss_doctor()
		elif doctor != null and is_instance_valid(doctor) and player != null \
				and doctor.global_position.distance_to(player.global_position) > 1400.0:
			dismiss_doctor()


func _ambient_color(theme: String) -> Color:
	match theme:
		"cemetery":
			return Color(0.24, 0.27, 0.30)
		"prison":
			return Color(0.24, 0.25, 0.26)
		"church":
			return Color(0.23, 0.22, 0.26)
		_:
			return Color(0.22, 0.25, 0.24)


func _spawn_pos(key: String) -> Vector2:
	var sp: Dictionary = level.get("spawns", {})
	var arr: Array = sp.get(key, [20, 12])
	return Vector2(float(arr[0]) * TILE, float(arr[1]) * TILE)


## Куда возвращает смерть: последняя точка сохранения этажа, иначе старт этажа.
func respawn_point() -> Vector2:
	var p := Game.checkpoint(str(level.get("id", "")))
	if p != Vector2.ZERO:
		return p
	return _spawn_pos("start")


func _tile_px(x: float, y: float) -> Vector2:
	return Vector2(x * TILE, y * TILE)


# --- геометрия -------------------------------------------------------------

func _build_walls() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var occluders := Node2D.new()
	add_child(occluders)

	var h := map.size()
	for y in h:
		var row := str(map[y])
		var x := 0
		while x < row.length():
			if row[x] != "#":
				x += 1
				continue
			var start := x
			while x < row.length() and row[x] == "#":
				x += 1
			var w := x - start
			var rect := Rect2i(start * TILE, y * TILE, w * TILE, TILE)
			var shape := CollisionShape2D.new()
			var rs := RectangleShape2D.new()
			rs.size = Vector2(rect.size)
			shape.shape = rs
			shape.position = Vector2(rect.position) + Vector2(rect.size) * 0.5
			body.add_child(shape)

			var oc := LightOccluder2D.new()
			var poly := OccluderPolygon2D.new()
			poly.polygon = PackedVector2Array([
				Vector2(0, 0), Vector2(rect.size.x, 0),
				Vector2(rect.size.x, rect.size.y), Vector2(0, rect.size.y),
			])
			oc.occluder = poly
			oc.position = Vector2(rect.position)
			occluders.add_child(oc)


# --- мебель ----------------------------------------------------------------

func _build_props(theme: String) -> void:
	for p in level.get("props", []):
		var name := str(p.get("t", ""))
		if name == "":
			continue
		var pos := _tile_px(float(p.get("x", 0)), float(p.get("y", 0)))
		var tex := Props.get_prop(theme, name)
		var size := Props.prop_size(name)

		var shadow := Sprite2D.new()
		shadow.texture = Tex.shadow_texture(int(size.x * 0.9), int(size.y * 0.28))
		shadow.position = pos + Vector2(2, size.y * 0.32)
		shadow.z_index = -2
		ysort.add_child(shadow)

		var spr := Sprite2D.new()
		spr.texture = tex
		spr.position = pos
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ysort.add_child(spr)

		if Levels.SOLID_PROPS.has(name):
			var body := StaticBody2D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			body.position = pos
			var shape := CollisionShape2D.new()
			var rs := RectangleShape2D.new()
			rs.size = Vector2(maxf(6.0, size.x - 6.0), maxf(6.0, size.y * 0.6))
			shape.shape = rs
			shape.position = Vector2(0, size.y * 0.12)
			body.add_child(shape)
			ysort.add_child(body)


# --- свет ------------------------------------------------------------------

func _build_lights() -> void:
	for l in level.get("lights", []):
		var pos := _tile_px(float(l.get("x", 0)), float(l.get("y", 0)))
		var radius := float(l.get("r", 180))
		var light := PointLight2D.new()
		light.texture = Tex.light_texture(256)
		light.texture_scale = radius / 128.0
		light.energy = float(l.get("e", 0.8))
		light.color = _color_from(l.get("c", [1.0, 1.0, 1.0]))
		light.position = pos
		light.z_index = 1
		if radius >= 170.0:
			light.shadow_enabled = true
			light.shadow_filter = PointLight2D.SHADOW_FILTER_PCF13
			light.shadow_filter_smooth = 2.0
		add_child(light)
		if bool(l.get("flicker", false)):
			_flicker.append([light, light.energy, randf() * TAU])


func _color_from(arr: Variant) -> Color:
	if arr is Array and arr.size() >= 3:
		return Color(float(arr[0]), float(arr[1]), float(arr[2]))
	return Color(1, 1, 1)


# --- объекты и враги -------------------------------------------------------

func _build_entities() -> void:
	var fid := str(level.get("id", "?"))
	for e in level.get("entities", []):
		var kind := str(e.get("t", ""))
		var d: Dictionary = e.duplicate(true)
		d["_floor"] = fid
		if kind == "enemy":
			_spawn_enemy(str(d.get("kind", "crawler")), _tile_px(float(d.get("x", 0)), float(d.get("y", 0))))
			continue
		if kind == "gas":
			_spawn_gas(d)
			continue
		if Game.flag("picked:%s:%d:%d" % [fid, int(d.get("x", 0)), int(d.get("y", 0))]):
			continue
		var it := Interactable.new()
		it.world = self
		it.data = d
		it.kind = kind
		it.position = _tile_px(float(d.get("x", 0)), float(d.get("y", 0)))
		ysort.add_child(it)
		_entity_nodes.append(it)

	# врагов, которых нужно добавить по флагу, здесь больше нет:
	# корпус Б заселяется сразу, а доктор приходит по сюжету.


func _spawn_gas(d: Dictionary) -> void:
	var pos := _tile_px(float(d.get("x", 0)), float(d.get("y", 0)))
	var radius := float(d.get("r", 2.0)) * TILE
	var fog := Sprite2D.new()
	fog.texture = Tex.light_texture(256, 1.6)
	fog.scale = Vector2.ONE * (radius / 128.0)
	fog.modulate = Color(0.42, 0.68, 0.72, 0.16)
	fog.position = pos
	fog.z_index = -3
	add_child(fog)
	var core := Sprite2D.new()
	core.texture = Tex.light_texture(256, 2.4)
	core.scale = Vector2.ONE * (radius / 190.0)
	core.modulate = Color(0.46, 0.72, 0.76, 0.10)
	core.position = pos + Vector2(18, -12)
	core.z_index = -3
	add_child(core)
	var t := create_tween()
	t.set_loops()
	t.tween_property(fog, "modulate:a", 0.28, 2.2).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(core, "position:x", pos.x - 22.0, 3.1).set_trans(Tween.TRANS_SINE)
	t.tween_property(fog, "modulate:a", 0.12, 2.8).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(core, "position:x", pos.x + 26.0, 3.4).set_trans(Tween.TRANS_SINE)
	_gas_zones.append({"pos": pos, "r": radius})


func gas_at(pos: Vector2) -> bool:
	for z in _gas_zones:
		if pos.distance_to(z["pos"]) <= float(z["r"]):
			return true
	return false


func _spawn_enemy(kind: String, pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.setup(kind, pos, player)
	ysort.add_child(e)
	return e


func spawn_enemies_near_player(kind: String, count: int) -> void:
	if player == null:
		return
	for i in count:
		var angle := randf() * TAU
		var dist := randf_range(120.0, 190.0)
		var pos := player.global_position + Vector2.from_angle(angle) * dist
		var tile := Vector2(int(pos.x / TILE), int(pos.y / TILE))
		if tile.x < 1 or tile.y < 1 or tile.y >= map.size() or tile.x >= str(map[int(tile.y)]).length():
			continue
		if str(map[int(tile.y)])[int(tile.x)] == "#":
			continue
		_spawn_enemy(kind, pos)
	Audio.play("scream", -6.0)


func spawn_pickup_effect(pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = Tex.dot_texture(24, Color(1.0, 0.92, 0.7, 0.8))
	s.position = pos + Vector2(0, -12)
	s.z_index = 5
	add_child(s)
	var t := create_tween()
	t.tween_property(s, "scale", Vector2(2.4, 2.4), 0.4)
	t.parallel().tween_property(s, "modulate:a", 0.0, 0.4)
	t.tween_callback(s.queue_free)


# --- камера и тряска -------------------------------------------------------

func _setup_camera() -> void:
	if player == null or player.camera == null:
		return
	var cam := player.camera
	var h := map.size()
	var w := 0
	for row in map:
		w = maxi(w, str(row).length())
	if w <= 0 or h <= 0:
		return
	var world_size := Vector2(w * TILE, h * TILE)
	var view_size := get_viewport_rect().size
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return
	# Этажи компактные, поэтому масштаб подбирается под экран: весь горизонт
	# виден целиком. Иначе камера упирается в лимиты (они уже видимой области)
	# и стоит на месте — Вера уходит за нижний/правый край и пропадает.
	var fit := minf(
		(view_size.x - CAMERA_MARGIN * 2.0) / world_size.x,
		(view_size.y - CAMERA_MARGIN * 2.0) / world_size.y)
	cam.zoom = Vector2.ONE * clampf(fit, CAMERA_MIN_ZOOM, CAMERA_MAX_ZOOM)
	var center := world_size * 0.5

	# Если горизонт помещается целиком, камера фиксируется по его центру.
	# Иначе она «дышит» на доли пикселя из-за целочисленных лимитов, а игрок
	# всё равно не выйдет за кадр — вся карта уже видна.
	if fit >= CAMERA_MIN_ZOOM:
		cam.top_level = true
		cam.position_smoothing_enabled = false
		cam.limit_left = -1000000
		cam.limit_top = -1000000
		cam.limit_right = 1000000
		cam.limit_bottom = 1000000
		cam.global_position = center
		cam.reset_smoothing()
		return

	# Большой этаж: камера идёт за Верой. Лимиты не должны быть меньше видимой
	# области — иначе Godot прижимает камеру к дальнему краю, а не центрирует.
	cam.top_level = false
	cam.position_smoothing_enabled = true
	var half := view_size / cam.zoom * 0.5
	cam.limit_left = int(floor(minf(0.0, center.x - half.x)))
	cam.limit_top = int(floor(minf(0.0, center.y - half.y)))
	cam.limit_right = int(ceil(maxf(world_size.x, center.x + half.x)))
	cam.limit_bottom = int(ceil(maxf(world_size.y, center.y + half.y)))
	cam.reset_smoothing()


func shake_small() -> void:
	_shake = maxf(_shake, 1.6)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _on_player_hurt(_amount: int) -> void:
	shake(4.5)
	Audio.play("heartbeat", -6.0)


func _on_prompt(text: String) -> void:
	prompt_changed.emit(text)


signal prompt_changed(text: String)


# --- события ---------------------------------------------------------------

func show_dialog(id: String) -> void:
	if id == "":
		return
	dialog_requested.emit(id)


func show_note(title: String, body: String) -> void:
	note_requested.emit(title, body)


func ask_code(it: Interactable) -> void:
	code_requested.emit(it)


func leave_floor(target: int) -> void:
	Game.player_pos = player.global_position
	if level.has("contract"):
		Game.finish_shift(level["contract"])
	floor_exit.emit(target)


func on_grave_dug(_it: Interactable, n: int) -> void:
	var splat := Sprite2D.new()
	splat.texture = Tex.blood_sprite(22, randi())
	splat.position = _it.global_position
	splat.z_index = -4
	add_child(splat)
	Game.toast("Знак вскрыт (%d/3)" % n)
	if n == 2:
		Game.add_item("key_crypt")
		Game.toast("В породе — Ключ штольни")
		Audio.play("reveal", -5.0)
	if n >= 3:
		Game.add_item("grave_key")
		Game.toast("Получен: Ключ подъёмника")
		Audio.play("reveal", -5.0)
		show_dialog("b4_gate_open")


## Ошибка в порядке у Тихона: выработка смыкается, порядок начинается заново.
func reset_graves() -> void:
	Game.flags["b4_dig"] = 0
	for it in get_tree().get_nodes_in_group("interactables"):
		if it is Interactable and it.kind == "grave":
			it.reset_dug()
	Game.toast("Выработка снова сомкнулась. Порядок — заново.")


func _hurt_player(amount: int) -> void:
	if player != null and is_instance_valid(player):
		player.hurt(amount, player.global_position)


func on_candle_lit(n: int) -> void:
	Game.toast("Лампа зажжена (%d/4)" % n)
	if n == 3:
		Game.set_flag("b2_third_lit")
		Audio.play("reveal", -6.0)
		Game.toast("Решётка пульта поднялась: четвёртая лампа открыта.")
	if n >= 4:
		Game.set_flag("b2_candles_lit")
		Audio.play("reveal", -4.0)
		Game.toast("Пульт открыт")
		for p in [Vector2(16, 22), Vector2(40, 22), Vector2(28, 28)]:
			_spawn_enemy("penitent", _tile_px(p.x, p.y))


func handle_action(action: String) -> void:
	match action:
		"doctor_first":
			show_dialog("doctor_first")
		"doctor_second":
			show_dialog("doctor_second")
		"doctor_third":
			show_dialog("doctor_third")
		"doctor_spawn":
			spawn_doctor()
		"wrong_code":
			_hurt_player(1)
			spawn_enemies_near_player("shadow", 1)
			Game.toast("Сейф взвыл. В коридоре кто-то отозвался.")
		"power_on":
			Game.set_flag("power")
			Audio.play("beep", -3.0)
		"ending_escape":
			_begin_ending("escape")
		"ending_truth":
			_begin_ending("truth")
		_:
			pass


func _begin_ending(id: String) -> void:
	if level.has("contract"):
		Game.finish_shift(level["contract"])
	ending_requested.emit(id)


## Доктор приходит из дальнего конца коридора: у игрока всегда есть путь к отступлению.
func spawn_doctor() -> void:
	if player == null or not is_instance_valid(player):
		return
	if doctor != null and is_instance_valid(doctor):
		doctor.queue_free()
		doctor = null
	var px := player.global_position.x
	var tile := Vector2(35.0, 13.5) if px < 640.0 else Vector2(4.0, 13.5)
	doctor = _spawn_enemy("doctor", _tile_px(tile.x, tile.y))
	_doctor_timer = 24.0
	Audio.play("scream", -7.0)
	shake(5.0)


func dismiss_doctor() -> void:
	_doctor_timer = 0.0
	if doctor != null and is_instance_valid(doctor):
		doctor.vanish()
		doctor = null
		Game.toast("Шаги стихли. Пока.")


func clear_doctor() -> void:
	_doctor_timer = 0.0
	if doctor != null and is_instance_valid(doctor):
		doctor.queue_free()
		doctor = null


# --- ввод ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and player != null and player.input_enabled and not Game.is_dead():
		player.try_interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_save"):
		if Game.save_game():
			Game.toast("Игра сохранена.")

