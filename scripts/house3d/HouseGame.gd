extends Node3D
## 3D-режим: особняк «Тихий Бор». Первое лицо, фонарь, три печати, Хозяйка дома.
## Карта — готовая модель assets/maps/haunted_house.glb (Sketchfab, CC-BY-4.0, Amy).
## Коллизия и точки расстановки строятся по геометрии карты при запуске.

const MODEL_PATH := "res://assets/maps/haunted_house.glb"
const MODEL_SCALE := 0.25
const FLOOR_Y := 2.36
const MODEL_MID_Z := -34.95
const SEAL_TOTAL := 3
const MAX_HEARTS := 3
const NOTE_RADIUS := 0.55

const NOTES := [
	{
		"id": "ledger",
		"title": "Дневник управляющего",
		"body": "Смена №9 ушла под дом в 23:40 и не вернулась.\n\nНасосы качают воду вторые сутки. Хозяйка запретила спускать людей в штрек. Она говорит, что дом должен спать.\n\nЯ не верю в дом, который спит. Я верю в дом, который ждёт.",
		"pos": Vector2(-6.6, -4.4),
	},
	{
		"id": "letter",
		"title": "Письмо горному инженеру",
		"body": "Вы просили не трогать восточную стену.\n\nЗа ней не пустота. За ней ход, и он дышит. Если вы всё-таки пробьёте — забирайте смену сами. Я в этом не участвую и никому не скажу, что вы меня звали.",
		"pos": Vector2(7.2, -4.6),
	},
	{
		"id": "roster",
		"title": "Список смены",
		"body": "Двенадцать фамилий. Одиннадцать зачёркнуты.\n\nДвенадцатым стоит моё имя. Я ещё не спускался.\n\nВнизу, другим почерком: «Он спустится».",
		"pos": Vector2(2.6, 5.2),
	},
	{
		"id": "book",
		"title": "Страница из книги",
		"body": "Три печати держат вход: соль, воск и имя.\n\nПока хоть одна цела — дом не выпустит. Когда все три снимут с мест, дверь сама отойдёт в сторону, и никто не должен стоять на пороге.",
		"pos": Vector2(0.0, 3.0),
	},
	{
		"id": "drawing",
		"title": "Детский рисунок",
		"body": "На рисунке дом. Под домом — длинный коридор.\n\nВ конце коридора кто-то стоит и держит лампу. У него нет лица, только две точки вместо глаз.\n\nПодписано печатными буквами: «ОНА ЖДЁТ, ПОКА ВСЕ ВЕРНУТСЯ».",
		"pos": Vector2(8.6, 5.4),
	},
]

const SEALS := [
	{"id": "salt", "label": "соль", "pos": Vector2(-7.4, -4.4)},
	{"id": "wax", "label": "воск", "pos": Vector2(7.4, -4.2)},
	{"id": "name", "label": "имя", "pos": Vector2(-7.6, 3.4)},
]

const BATTERIES := [Vector2(8.4, -1.2), Vector2(-8.8, 5.2)]

var player: HousePlayer
var ghost: HouseGhost
var hud: ManorHud

var hearts := MAX_HEARTS
var seals_taken := 0
var notes_read := 0
var started := false
var finished := false
var exit_open := false

var _model: Node3D
var _world_body: StaticBody3D
var _cells: Array[Vector3] = []
var _space: PhysicsDirectSpaceState3D
var _sphere_probe: SphereShape3D
var _candles: Array = []
var _exit_blocker: StaticBody3D
var _exit_planks: Node3D
var _exit_trigger: Area3D
var _exit_interact: HouseInteract
var _creak_timer := 18.0
var _seal_marks: Array[String] = []
var _capture: Node = null
var _loading: CanvasLayer = null
var _removed_meshes: Array[Node] = []
var _moon: DirectionalLight3D = null
var _env: Environment = null
var _hint_capture := false


func _ready() -> void:
	randomize()
	get_tree().paused = false
	_register_input()
	_setup_audio()
	_show_loading()
	await get_tree().process_frame
	await get_tree().process_frame
	_build_environment()
	_load_map()
	_carve_front_opening()
	_build_collision()
	_build_outside()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_build_walk_grid()
	_spawn_player()
	_spawn_props()
	_spawn_ghost()
	_build_hud()
	_build_exit()
	_hide_loading()
	Settings.graphics_changed.connect(_apply_graphics)
	_apply_graphics()

	started = true
	if OS.get_cmdline_user_args().has("--capture-3d") or OS.get_cmdline_args().has("--capture-3d"):
		var cap_script: GDScript = load("res://dev/capture3d.gd")
		if cap_script != null:
			_capture = cap_script.new()
			add_child(_capture)
			_capture.setup(self)
	elif OS.get_cmdline_user_args().has("--playtest-3d") or OS.get_cmdline_args().has("--playtest-3d"):
		var test_script: GDScript = load("res://dev/playtest3d.gd")
		if test_script != null:
			var tester: Node = test_script.new()
			add_child(tester)
			tester.setup(self)
	elif OS.get_cmdline_user_args().has("--roundtrip") or OS.get_cmdline_args().has("--roundtrip"):
		var rt_script: GDScript = load("res://dev/roundtrip3d.gd")
		if rt_script != null:
			var rt: Node = rt_script.new()
			get_tree().root.add_child.call_deferred(rt)
			rt.set_meta("game", self)
			rt.call_deferred("setup", self)
	elif OS.get_cmdline_user_args().has("--bench-3d") or OS.get_cmdline_args().has("--bench-3d"):
		var bench_script: GDScript = load("res://dev/bench3d.gd")
		if bench_script != null:
			var bench: Node = bench_script.new()
			add_child(bench)
			bench.setup(self)


func _register_input() -> void:
	_add_key("flashlight", [KEY_F])
	_add_key("crouch", [KEY_CTRL, KEY_C])
	if not InputMap.has_action("interact"):
		_add_key("interact", [KEY_E, KEY_ENTER, KEY_KP_ENTER])


func _add_key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		if not InputMap.action_has_event(action, ev):
			InputMap.action_add_event(action, ev)


func _setup_audio() -> void:
	Audio.start_ambient("cemetery")
	Audio.set_master_volume(Settings.volume)


func _show_loading() -> void:
	_loading = CanvasLayer.new()
	_loading.layer = 30
	add_child(_loading)
	var bg := ColorRect.new()
	bg.color = Color(0.008, 0.009, 0.013, 1.0)
	UiTheme.fullscreen(bg)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_loading.add_child(bg)
	var title := UiTheme.make_label("ОСОБНЯК «ТИХИЙ БОР»", 34, Color(0.88, 0.85, 0.78))
	title.position = Vector2(96, 300)
	_loading.add_child(title)
	var sub := UiTheme.make_label("дом просыпается…", 15, UiTheme.DIM)
	sub.position = Vector2(100, 356)
	_loading.add_child(sub)


func _hide_loading() -> void:
	if _loading != null:
		_loading.queue_free()
		_loading = null


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnv"
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.012, 0.016, 0.032)
	sky_mat.sky_horizon_color = Color(0.07, 0.078, 0.1)
	sky_mat.ground_bottom_color = Color(0.008, 0.008, 0.012)
	sky_mat.ground_horizon_color = Color(0.03, 0.03, 0.04)
	sky_mat.sun_angle_max = 8.0
	sky_mat.sky_curve = 0.12
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.65
	env.ambient_light_energy = 1.15
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.055, 0.062, 0.085)
	env.fog_light_energy = 0.7
	env.fog_density = 0.014
	env.fog_sky_affect = 0.45
	env.fog_height = 0.0
	env.fog_height_density = 0.0
	we.environment = env
	_env = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.52, 0.62, 0.92)
	moon.light_energy = 0.72
	moon.rotation_degrees = Vector3(-58, 32, 0)
	moon.shadow_enabled = true
	# Один ортогональный каскад вместо четырёх PSSM: дом маленький, разницы почти
	# не видно, а кадров на встроенной графике заметно больше.
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	moon.directional_shadow_max_distance = 30.0
	moon.shadow_blur = 1.3
	moon.shadow_bias = 0.04
	add_child(moon)
	_moon = moon


## Настройки графики из паузы: тени и туман можно выключить на слабой машине.
func _apply_graphics() -> void:
	if _moon != null:
		_moon.shadow_enabled = Settings.shadows
	if player != null and player.flashlight != null:
		player.flashlight.shadow_enabled = Settings.shadows
	if _env != null:
		_env.fog_enabled = Settings.fog


func _load_map() -> void:
	var packed: PackedScene = load(MODEL_PATH)
	if packed == null:
		push_error("Не удалось загрузить карту %s" % MODEL_PATH)
		return
	_model = packed.instantiate()
	_model.scale = Vector3.ONE * MODEL_SCALE
	_model.position = Vector3(0.0, -FLOOR_Y * MODEL_SCALE, -MODEL_MID_Z * MODEL_SCALE)
	add_child(_model)
	_print_map_info()


func _print_map_info() -> void:
	var meshes := _collect_meshes(_model)
	print("HOUSE3D map meshes=%d" % meshes.size())


## В готовой модели фасад зашит наглухо: дверное полотно вмуровано в стену.
## Вырезаем центральную часть фасада и само полотно, чтобы получился настоящий
## проём под завал. Всё остальное (боковые стены, крыльцо, пол) остаётся на месте.
func _carve_front_opening() -> void:
	for node in _collect_meshes(_model):
		var mi: MeshInstance3D = node
		if mi.mesh == null:
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		var c := b.get_center()
		var looks_like_front_panel := absf(c.x) < 0.6 \
			and b.position.z > 6.9 and b.position.z < 7.2 \
			and b.size.z < 0.4 \
			and b.size.x > 1.0 \
			and b.size.y > 0.8 \
			and b.position.y < 0.15
		if looks_like_front_panel:
			mi.visible = false
			_removed_meshes.append(mi)
	print("HOUSE3D front opening meshes removed=%d" % _removed_meshes.size())


func _build_collision() -> void:
	_world_body = StaticBody3D.new()
	_world_body.name = "HouseCollision"
	_world_body.collision_layer = 1
	_world_body.collision_mask = 0
	add_child(_world_body)
	var count := 0
	for node in _collect_meshes(_model):
		var mi: MeshInstance3D = node
		if mi.mesh == null or _removed_meshes.has(mi):
			continue
		var shape := mi.mesh.create_trimesh_shape()
		if shape == null:
			continue
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = mi.global_transform
		_world_body.add_child(cs)
		count += 1
	print("HOUSE3D collision shapes=%d" % count)


func _build_outside() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(220.0, 220.0)
	ground.mesh = plane
	ground.position = Vector3(0, 0.015, 0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.05, 0.058, 0.052)
	gmat.roughness = 1.0
	ground.material_override = gmat
	add_child(ground)

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.035, 0.032, 0.03)
	trunk_mat.roughness = 1.0

	# Все деревья — один меш: сотня узлов и вызовов отрисовки не нужна ради silhouettes.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(trunk_mat)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261109
	for i in 26:
		var ang := rng.randf() * TAU
		var radius := rng.randf_range(17.0, 46.0)
		var x := cos(ang) * radius
		var z := sin(ang) * radius
		# не загораживаем крыльцо прямо перед входом
		if absf(x) < 4.0 and z > 0.0 and z < 26.0:
			continue
		var tree_xf := Transform3D(Basis(), Vector3(x, 0.0, z))
		var h := rng.randf_range(3.4, 6.8)
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.07
		trunk.bottom_radius = 0.16
		trunk.height = h
		st.append_from(trunk, 0, tree_xf * Transform3D(Basis(), Vector3(0, h * 0.5, 0)))
		for b in 3:
			var branch := CylinderMesh.new()
			branch.top_radius = 0.02
			branch.bottom_radius = 0.06
			branch.height = rng.randf_range(1.2, 2.4)
			var a := rng.randf() * TAU
			var bpos := Vector3(cos(a) * 0.5, h * rng.randf_range(0.55, 0.95), sin(a) * 0.5)
			var brot := Vector3(rng.randf_range(-0.9, 0.9), a, rng.randf_range(-0.9, 0.9))
			var bxf := Transform3D(Basis.from_euler(brot), bpos)
			st.append_from(branch, 0, tree_xf * bxf)
	var trees := MeshInstance3D.new()
	trees.name = "DeadTrees"
	trees.mesh = st.commit()
	trees.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trees)


func _build_walk_grid() -> void:
	_space = get_world_3d().direct_space_state
	_sphere_probe = SphereShape3D.new()
	_sphere_probe.radius = 0.32
	var ray := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.DOWN, 1)
	var x := -10.0
	while x <= 10.0:
		var z := -6.6
		while z <= 6.6:
			ray.from = Vector3(x, 2.4, z)
			ray.to = Vector3(x, -0.8, z)
			var hit := _space.intersect_ray(ray)
			if not hit.is_empty():
				var p: Vector3 = hit.get("position")
				if p.y > -0.15 and p.y < 0.35 and _clearance(Vector3(x, p.y, z)):
					_cells.append(Vector3(x, p.y, z))
			z += 0.55
		x += 0.55
	print("HOUSE3D walk cells=%d" % _cells.size())


func _clearance(point: Vector3) -> bool:
	for h in [0.48, 1.15]:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = _sphere_probe
		q.transform = Transform3D(Basis(), Vector3(point.x, point.y + h, point.z))
		q.collision_mask = 1
		q.collide_with_bodies = true
		q.collide_with_areas = false
		if not _space.intersect_shape(q, 1).is_empty():
			return false
	return true


func _snap(point: Vector2) -> Vector3:
	var best := Vector3(point.x, 0.0, point.y)
	var best_dist := 1e9
	for c in _cells:
		var d := Vector2(c.x - point.x, c.z - point.y).length()
		if d < best_dist:
			best_dist = d
			best = c
	if best_dist > 6.0:
		return Vector3(point.x, 0.0, point.y)
	return best


func _spawn_player() -> void:
	var spawn := _snap(Vector2(0.0, 5.9))
	player = HousePlayer.new()
	player.position = Vector3(spawn.x, spawn.y + 0.92, spawn.z)
	add_child(player)
	player.target_changed.connect(_on_target_changed)
	player.interact_requested.connect(_on_interact)
	player.battery_changed.connect(_on_battery_changed)
	player.flashlight_changed.connect(_on_flashlight_changed)
	player.stepped.connect(_on_step)


func _on_battery_changed(value: float) -> void:
	if hud != null:
		hud.set_battery(value)


func _on_flashlight_changed(on: bool) -> void:
	if hud != null:
		hud.set_flashlight(on)


func _on_step(loud: bool) -> void:
	Audio.play("step_soft" if not loud else "step", -10.0, randf_range(0.92, 1.08))


func _spawn_props() -> void:
	for n in NOTES:
		var pos := _snap(n["pos"])
		var it := _make_interact("note", pos + Vector3(0, 1.35, 0), "Прочитать")
		it.id = n["id"]
		it.title = n["title"]
		it.body = n["body"]

	for s in SEALS:
		var pos := _snap(s["pos"])
		var it := _make_interact("seal", pos + Vector3(0, 1.0, 0), "Взять печать")
		it.id = s["id"]
		it.title = s["label"]

	for b in BATTERIES:
		var pos := _snap(b)
		var it := _make_interact("battery", pos + Vector3(0, 0.85, 0), "Взять батарею")
		it.id = "battery"


func _make_interact(kind: String, pos: Vector3, prompt: String) -> HouseInteract:
	var it := HouseInteract.new()
	it.kind = kind
	it.prompt = prompt
	it.position = pos
	add_child(it)
	return it


func _add_candle(pos: Vector3, color: Color, energy: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = pos
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = 5.0
	lamp.omni_attenuation = 1.6
	lamp.shadow_enabled = false
	add_child(lamp)
	_candles.append({"light": lamp, "base": energy, "phase": randf() * TAU})

	# маленький огонёк, чтобы источник света было видно
	var flame := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.09
	flame.mesh = sphere
	flame.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.75, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.65, 0.3)
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.material_override = mat
	add_child(flame)
	_candles.append({"light": null, "mesh": flame, "base": 1.0, "phase": randf() * TAU})


func _spawn_ghost() -> void:
	ghost = HouseGhost.new()
	ghost.player = player
	ghost.cells = _cells
	var spot := _far_cell(player.global_position)
	ghost.position = spot + Vector3(0, 1.0, 0)
	add_child(ghost)
	ghost.touched.connect(_on_ghost_touched)


func _far_cell(from: Vector3) -> Vector3:
	var best := Vector3(0, 0, -5)
	var best_d := -1.0
	for c in _cells:
		var d := c.distance_to(from)
		if d > best_d:
			best_d = d
			best = c
	return best


func _build_hud() -> void:
	hud = ManorHud.new()
	add_child(hud)
	hud.set_hearts(hearts)
	hud.set_battery(player.battery)
	hud.set_flashlight(player.light_on)
	_update_objective()
	hud.resume_requested.connect(_on_resume)
	hud.pause_requested.connect(_on_pause)
	hud.restart_requested.connect(_restart)
	hud.menu_requested.connect(_to_menu)
	hud.note_closed.connect(_on_note_closed)
	hud.show_intro(
		"Ты вошла в дом, чтобы найти смену брата.\n"
		+ "Три печати держат вход: соль, воск и имя.\n"
		+ "Сними их — и уходи, пока Хозяйка спит.",
		3.2)
	Audio.play("door", -6.0, 0.8)


func _build_exit() -> void:
	# Завал в проёме: пока печати целы, отсюда не выйти.
	_exit_blocker = StaticBody3D.new()
	_exit_blocker.collision_layer = 1
	_exit_blocker.collision_mask = 0
	_exit_blocker.position = Vector3(0, 1.5, 7.0)
	add_child(_exit_blocker)
	var box := BoxShape3D.new()
	box.size = Vector3(7.2, 3.0, 0.35)
	var cs := CollisionShape3D.new()
	cs.shape = box
	_exit_blocker.add_child(cs)

	_exit_planks = Node3D.new()
	_exit_planks.position = Vector3(0, 0, 7.0)
	add_child(_exit_planks)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.22, 0.15, 0.1)
	wood.roughness = 0.9
	for i in 5:
		var plank := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(6.6, 0.34, 0.12)
		plank.mesh = pm
		plank.material_override = wood
		plank.position = Vector3(randf_range(-0.15, 0.15), 0.55 + i * 0.55, randf_range(-0.04, 0.04))
		plank.rotation_degrees = Vector3(0, 0, randf_range(-1.5, 1.5))
		_exit_planks.add_child(plank)

	_exit_interact = _make_interact("exit", Vector3(0, 1.25, 6.45), "Снять засов")
	_exit_interact.title = "Выход"

	_exit_trigger = Area3D.new()
	_exit_trigger.collision_layer = 0
	_exit_trigger.collision_mask = 2
	_exit_trigger.monitoring = true
	_exit_trigger.position = Vector3(0, 1.2, 9.2)
	var ts := BoxShape3D.new()
	ts.size = Vector3(7.0, 2.6, 2.0)
	var tcs := CollisionShape3D.new()
	tcs.shape = ts
	_exit_trigger.add_child(tcs)
	add_child(_exit_trigger)
	_exit_trigger.body_entered.connect(_on_exit_body)


func _update_objective() -> void:
	if hud == null:
		return
	if exit_open:
		hud.set_objective("ВЫХОД ОТКРЫТ", "Иди на крыльцо. Не оборачивайся.")
		return
	var left: Array[String] = []
	for s in SEALS:
		if not _seal_marks.has(s["id"]):
			left.append(s["label"])
	hud.set_objective("ПЕЧАТИ: %d / %d" % [seals_taken, SEAL_TOTAL], "Осталось: " + ", ".join(PackedStringArray(left)))


func _process(delta: float) -> void:
	if not started:
		return
	var t := Time.get_ticks_msec() / 1000.0
	for c in _candles:
		var phase: float = c["phase"]
		var base: float = c["base"]
		var flicker := 0.82 + 0.18 * sin(t * 7.3 + phase) + 0.09 * sin(t * 17.1 + phase * 2.0)
		if c.has("light") and c["light"] != null:
			c["light"].light_energy = base * flicker
		if c.has("mesh") and c["mesh"] != null:
			c["mesh"].scale = Vector3.ONE * (0.85 + flicker * 0.25)

	_creak_timer -= delta
	if _creak_timer <= 0.0:
		_creak_timer = randf_range(22.0, 45.0)
		Audio.play("door", -26.0, randf_range(0.55, 0.75))

	if hud != null:
		var want_hint := not get_tree().paused and not finished \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
		if want_hint != _hint_capture:
			_hint_capture = want_hint
			hud.set_capture_hint(want_hint)


func _input(event: InputEvent) -> void:
	# Клик по окну возвращает захват мыши, если его потеряли (alt-tab, встроенный
	# в редактор режим, неудачный старт). Сама мышь вращает камеру и без захвата.
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT \
				and not get_tree().paused and not finished \
				and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	if not is_inside_tree() or not started:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not get_tree().paused and not finished:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if not get_tree().paused and not finished:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_target_changed(target: Node) -> void:
	if hud == null:
		return
	if target is HouseInteract:
		var it: HouseInteract = target
		hud.show_prompt("[E] " + it.prompt)
	else:
		hud.show_prompt("")


func _on_interact(target: Node) -> void:
	if target == null or not is_instance_valid(target) or finished:
		return
	var it: HouseInteract = target
	if it.done:
		return
	match it.kind:
		"note":
			it.done = true
			it.consume()
			notes_read += 1
			Audio.play("note", -4.0)
			hud.show_note(it.title, it.body)
			get_tree().paused = true
			player.set_can_move(false)
		"seal":
			_take_seal(it)
		"battery":
			it.done = true
			it.consume()
			player.add_battery(45.0)
			Audio.play("pickup", -4.0)
			hud.toast("Батарея. Фонарь ещё посветит.")
		"exit":
			_try_exit()


func _take_seal(it: HouseInteract) -> void:
	it.done = true
	seals_taken += 1
	_seal_marks.append(it.id)
	Audio.play("candle", -2.0)
	hud.toast("Печать «%s» снята. %d из %d." % [it.title, seals_taken, SEAL_TOTAL])
	it.queue_free()
	_update_objective()
	if seals_taken == 1:
		ghost.awaken()
		hud.toast("Что-то проснулось в глубине дома.", 4.0)
		hud.flash_damage(0.35)
	if seals_taken >= SEAL_TOTAL:
		_unlock_exit()


func _unlock_exit() -> void:
	if exit_open:
		return
	exit_open = true
	_update_objective()
	Audio.play("door", -3.0, 0.7)
	hud.toast("Все три печати сняты. Завал у входа осыпался.", 5.0)
	if _exit_blocker != null:
		_exit_blocker.queue_free()
		_exit_blocker = null
	if _exit_interact != null:
		_exit_interact.queue_free()
		_exit_interact = null
	if _exit_planks != null:
		var tween := create_tween()
		tween.tween_property(_exit_planks, "position:y", -2.5, 1.6).set_trans(Tween.TRANS_QUAD)
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			if _exit_planks != null:
				_exit_planks.queue_free()
				_exit_planks = null)
	if ghost != null:
		ghost.start_hunt_now()


func _try_exit() -> void:
	if exit_open:
		return
	Audio.play("door_locked", -4.0)
	hud.toast("Завал не сдвинуть. Нужны все три печати: соль, воск и имя.", 4.0)


func _on_exit_body(body: Node3D) -> void:
	if body == player and exit_open:
		_win()


func _on_ghost_touched() -> void:
	if finished:
		return
	if not player.take_hit(ghost.global_position):
		return
	hearts -= 1
	hud.set_hearts(hearts)
	hud.flash_damage(0.85)
	Audio.play("hurt", -2.0)
	if hearts <= 0:
		_die()
	else:
		hud.toast("Хозяйка коснулась тебя. Не стой на месте.", 3.0)


func _die() -> void:
	if finished:
		return
	finished = true
	player.set_can_move(false)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_death()
	Audio.play("death", -2.0)


func _win() -> void:
	if finished:
		return
	finished = true
	player.set_can_move(false)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var text := "Ты выходишь на крыльцо. Ветер пахнет мокрой землёй.\n\n" \
		+ "За спиной дом закрывает дверь сам — тихо, без скрипа.\n" \
		+ "Смена, которую ты искала, осталась внутри. Но теперь ты знаешь её имена.\n\n" \
		+ "Прочитано записей: %d из %d. Печатей снято: %d." % [notes_read, NOTES.size(), seals_taken]
	hud.show_win(text)
	Audio.play("door", -2.0, 0.7)
	Audio.start_ambient("menu")


func _on_pause() -> void:
	if finished:
		return
	get_tree().paused = true
	player.set_can_move(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_pause()


func _on_resume() -> void:
	hud.hide_pause()
	get_tree().paused = false
	player.set_can_move(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_note_closed() -> void:
	get_tree().paused = false
	if player != null:
		player.set_can_move(true)
	if player != null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _restart() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().call_deferred("reload_current_scene")


func _to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Audio.start_ambient("menu")
	get_tree().call_deferred("change_scene_to_file", "res://scenes/Main.tscn")


func _collect_meshes(root: Node) -> Array:
	var res: Array = []
	if root == null:
		return res
	if root is MeshInstance3D:
		res.append(root)
	for c in root.get_children():
		res.append_array(_collect_meshes(c))
	return res
