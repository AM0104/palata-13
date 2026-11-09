extends Node2D
## Точка входа: меню, загрузка этажей, постобработка, управление экранами.

var ui: UiRoot
var world: World
var post_mat: ShaderMaterial

var _restore_pos := false
var _flash := 0.0
var _pulse := 0.0
var _dark := 0.0
var _state := "menu"
var _diff_origin := "menu"   ## откуда открыто окно сложности: "menu" или "ending"


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.01, 0.01, 0.015))
	_setup_post()

	ui = UiRoot.new()
	add_child(ui)
	ui.setup(self)
	ui.new_game_requested.connect(_request_new_game)
	ui.continue_requested.connect(_on_continue)
	ui.house_requested.connect(_on_house3d)
	ui.quit_requested.connect(func() -> void: get_tree().quit())
	ui.resume_requested.connect(_on_resume)
	ui.save_requested.connect(_on_save)
	ui.to_menu_requested.connect(_on_to_menu)
	ui.retry_requested.connect(_on_retry)
	ui.restart_requested.connect(_request_new_game)
	ui.dialog.finished.connect(_update_pause)
	ui.difficulty_chosen.connect(_on_difficulty_chosen)
	ui.difficulty_ui.cancelled.connect(_on_difficulty_cancelled)

	Game.player_died.connect(_on_died)
	Game.hp_changed.connect(_on_hp_changed)
	Game.floor_changed.connect(func(_i: int) -> void: pass)

	ui.show_main_menu()

	if _wants("--walkcheck"):
		add_child(load("res://dev/walkcheck.gd").new())
	elif _wants("--stage1-shots"):
		add_child(load("res://dev/stage1_shots.gd").new())
	elif _wants("--capture-stage2"):
		add_child(load("res://dev/capture_stage2.gd").new())
	elif _wants("--debug-doctor"):
		add_child(load("res://dev/debug_doctor.gd").new())
	elif _wants_capture():
		var cap: Node = load("res://dev/capture.gd").new()
		add_child(cap)
	elif _wants("--survival-test"):
		add_child(load("res://dev/survival_test.gd").new())
	elif _wants("--playtest"):
		add_child(load("res://dev/playtest.gd").new())
	elif _wants("--choice-test"):
		add_child(load("res://dev/choice_test.gd").new())
	elif _wants("--map-test"):
		add_child(load("res://dev/map_test.gd").new())
	elif _wants("--door-test"):
		add_child(load("res://dev/door_test.gd").new())
	elif _wants("--map-dump"):
		add_child(load("res://dev/map_dump.gd").new())
	elif _wants("--door-scan"):
		add_child(load("res://dev/door_scan.gd").new())
	elif _wants("--door-walk"):
		add_child(load("res://dev/door_walk.gd").new())
	elif _wants("--interact-test"):
		add_child(load("res://dev/interact_test.gd").new())
	elif _wants("--tween-probe"):
		add_child(load("res://dev/tween_probe.gd").new())
	elif _wants("--art-test"):
		add_child(load("res://dev/art_test.gd").new())
	elif _wants("--door-preview"):
		add_child(load("res://dev/door_preview.gd").new())
	elif _wants("--window-test"):
		add_child(load("res://dev/window_test.gd").new())
	elif _wants("--difficulty-test"):
		add_child(load("res://dev/difficulty_test.gd").new())
	elif _wants("--companion-test"):
		add_child(load("res://dev/companion_test.gd").new())
	elif _wants("--test-menu3d"):
		add_child(load("res://dev/menu3d_test.gd").new())


func _wants(flag: String) -> bool:
	return OS.get_cmdline_user_args().has(flag) or OS.get_cmdline_args().has(flag)


func _wants_capture() -> bool:
	return _wants("--capture")


func _setup_post() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	if _wants("--no-post"):
		return
	# Постобработка бывает двух видов. На Forward+/Mobile кадр читается экранной
	# текстурой (hint_screen_texture). На Compatibility (и в веб-сборке) экранная
	# текстура не читается — приходит белой, поэтому там включается вариант
	# post_gl.gdshader, который строит эффект наложением. Признак рендерера —
	# отсутствие RenderingDevice.
	var uses_device := RenderingServer.get_rendering_device() != null
	var path := "res://assets/shaders/post.gdshader" if uses_device else "res://assets/shaders/post_gl.gdshader"
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.color = Color(1, 1, 1, 1)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	var shader := load(path)
	if shader != null:
		post_mat.shader = shader
	rect.material = post_mat
	layer.add_child(rect)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.2)
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 1.6)
	if post_mat != null:
		post_mat.set_shader_parameter("damage_flash", _flash)
		post_mat.set_shader_parameter("pulse", _pulse)


# --- загрузка этажей -------------------------------------------------------

func load_floor(index: int, restore_pos: bool = false) -> void:
	if world != null and is_instance_valid(world):
		world.queue_free()
	world = World.new()
	add_child(world)
	world.dialog_requested.connect(ui.show_dialog)
	world.note_requested.connect(ui.show_note)
	world.code_requested.connect(ui.show_code)
	world.floor_exit.connect(_on_floor_exit)
	world.ending_requested.connect(ui.show_ending)
	world.build(index)
	ui.bind_world(world)
	ui.set_hud_visible(true)
	if restore_pos and Game.player_pos != Vector2.ZERO:
		world.player.teleport(Game.player_pos)
	_pulse = 0.6


func _update_pause() -> void:
	ui._update_pause()


# --- сложность -------------------------------------------------------------

## «Новая игра» и «Пройти заново» сначала спрашивают сложность.
## Другого входа в выбор сложности нет: из меню уровень не меняется.
func _request_new_game() -> void:
	_diff_origin = "ending" if ui.end_ui.visible else "menu"
	ui.show_difficulty()


func _on_difficulty_chosen(index: int) -> void:
	Game.set_difficulty(index)
	_on_new_game()


func _on_difficulty_cancelled() -> void:
	if _diff_origin == "ending" and Game.ending != "":
		ui.show_ending(Game.ending)
	else:
		ui.show_main_menu()


func _on_new_game() -> void:
	Game.new_game()
	ui.hide_all()
	_restore_pos = false
	Game.set_floor(0)
	load_floor(0)


func _on_continue() -> void:
	if Game.load_game():
		ui.hide_all()
		load_floor(Game.floor_index, true)
	else:
		_on_new_game()


## Переход в отдельный 3D-режим. 2D-партия и сохранение не трогаются:
## сцена заменяется целиком, состояние Game остаётся на месте.
func _on_house3d() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if world != null and is_instance_valid(world):
		world.queue_free()
		world = null
	if ui != null:
		ui.close_modals()
	Audio.stop_ambient(0.25)
	get_tree().call_deferred("change_scene_to_file", "res://scenes/House3D.tscn")


func _on_resume() -> void:
	ui.close_modals()


func _on_save() -> void:
	if Game.save_game():
		Game.toast("Игра сохранена. %s" % Game.format_time())
	else:
		Game.toast("Не удалось сохранить.")


func _on_to_menu() -> void:
	if world != null and is_instance_valid(world):
		Game.player_pos = world.player.global_position
		world.queue_free()
		world = null
	Game.abandon_run()
	ui.show_main_menu()
	Audio.start_ambient("menu")


func _on_floor_exit(target: int) -> void:
	Game.set_floor(target)
	Audio.play("door", -3.0)
	var report := Game.last_shift_report.duplicate(true)
	load_floor(target)
	ui.show_floor_transition(report, target)


func _on_retry() -> void:
	# смерть возвращает к точке сохранения этажа и не лечит: прогресс цел, сердце одно
	Game.revive_at_checkpoint()
	ui.hide_all()
	if world != null and is_instance_valid(world):
		var back := world.respawn_point()
		world.clear_doctor()
		world.player.teleport(back)
		world.player._invuln = 2.0
		ui.set_hud_visible(true)
		ui._update_pause()
		Game.toast("Ты возвращаешься к последней записанной точке. Одно сердце.")
	else:
		load_floor(Game.floor_index)


func _on_died() -> void:
	Audio.play("scream", -4.0)
	ui.show_death()


func _on_hp_changed() -> void:
	_flash = 1.0
	_pulse = 1.0


# --- ввод ------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if ui == null:
		return
	if ui.menu.visible or ui.end_ui.visible or ui.difficulty_ui.visible:
		return
	if event.is_action_pressed("pause"):
		if ui.any_modal():
			ui.close_modals()
		else:
			ui.show_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		if world != null:
			ui.toggle_inventory("items")
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("journal"):
		if world != null:
			ui.toggle_inventory("journal")
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map"):
		if world != null:
			ui.toggle_map()
			get_viewport().set_input_as_handled()


# --- отладочные хуки (используются в dev/capture.gd) -----------------------

func dev_state() -> String:
	return _state


func dev_ready() -> bool:
	return ui != null and world != null and is_instance_valid(world)




