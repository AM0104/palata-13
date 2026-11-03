extends Node
## Пользовательские настройки: режим окна и громкость.
## Хранятся в user://settings.cfg, поэтому выбор игрока переживает перезапуск.

signal volume_changed(value: float)
signal fullscreen_changed(on: bool)

const CONFIG_NAME := "settings.cfg"
const DEFAULT_VOLUME := 0.8
const SAVE_DELAY := 0.4

var volume: float = DEFAULT_VOLUME
var fullscreen: bool = false

var _save_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_input()

	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer.timeout.connect(save_settings)
	add_child(_save_timer)

	load_settings()
	Audio.set_master_volume(volume)
	_apply_window_mode()


# --- ввод ------------------------------------------------------------------

func _register_input() -> void:
	if not InputMap.has_action("fullscreen"):
		InputMap.add_action("fullscreen")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F11
	InputMap.action_add_event("fullscreen", ev)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("fullscreen"):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


# --- громкость -------------------------------------------------------------

func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	Audio.set_master_volume(volume)
	_save_soon()
	volume_changed.emit(volume)


# --- полный экран ----------------------------------------------------------

func set_fullscreen(on: bool) -> void:
	var changed := fullscreen != on
	fullscreen = on
	_apply_window_mode()
	_save_soon()
	if changed:
		fullscreen_changed.emit(fullscreen)


func toggle_fullscreen() -> void:
	set_fullscreen(not fullscreen)


## Фактическое состояние окна (учитывает переключение по F11 или средствами ОС).
func is_fullscreen() -> bool:
	if not window_available():
		return fullscreen
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


## Во встроенном в редактор и headless-окне переключать нечего: там нет окна ОС.
func window_available() -> bool:
	return not _headless() and not _embedded()


func window_hint() -> String:
	if _headless():
		return "Запуск без окна (headless): режим экрана недоступен."
	if _embedded():
		return "Игра идёт внутри редактора, поэтому окно не переключается. Отключите " \
			+ "Editor Settings → Run → Window Placement → Game Embed Mode или запустите игру отдельно."
	return "F11 — переключить полноэкранный режим в любой момент."


func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _embedded() -> bool:
	return Engine.is_embedded_in_editor()


func _apply_window_mode() -> void:
	if not window_available():
		return
	var before := DisplayServer.window_get_mode()
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if before == want:
		return
	DisplayServer.window_set_mode(want)
	if before == DisplayServer.WINDOW_MODE_FULLSCREEN and want == DisplayServer.WINDOW_MODE_WINDOWED:
		_center_window()


## Выход из полного экрана: возвращаем окно в центр рабочего стола.
func _center_window() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var size := DisplayServer.window_get_size()
	DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)


# --- файл настроек ---------------------------------------------------------

## Настройки лежат рядом с сохранениями: тот же портируемый каталог, что выбирает Game
## (res://saves при запуске из проекта, user://saves в собранной игре).
func config_path() -> String:
	return Game.save_dir() + "/" + CONFIG_NAME


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(config_path()) != OK:
		return
	volume = clampf(float(cfg.get_value("audio", "volume", DEFAULT_VOLUME)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("display", "fullscreen", false))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.save(config_path())


func _save_soon() -> void:
	if _save_timer != null:
		_save_timer.start()