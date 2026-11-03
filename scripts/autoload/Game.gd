extends Node
## Глобальное состояние игры: здоровье, инвентарь, журнал, флаги, этажи и сохранения.
## Автолоад: к нему обращаются все сцены как `Game`.

signal hp_changed
signal inventory_changed
signal notes_changed
signal flags_changed
signal toast_requested(text: String)
signal player_died
signal floor_changed(index: int)
signal difficulty_changed
signal lamp_changed
signal air_changed

const MAX_HP := 6
const MAX_LAMP := 100.0
const MAX_AIR := 100.0
const SAVE_NAME := "save1.json"

## Уровни сложности. Таблица одна — её читают враги, Клим и здоровье Веры.
const DIFF_EASY := 0
const DIFF_NORMAL := 1
const DIFF_HARD := 2
const DIFFICULTY_NAMES := ["ГОСТЬ", "ПАЦИЕНТ", "ПАЛАТА 13"]
const DIFFICULTY_TAGS := ["ПЕРВЫЙ ЗАХОД", "РЕКОМЕНДУЕТСЯ", "ТОЛЬКО ДЛЯ СМЕЛЫХ"]
const DIFFICULTY_DESC := [
	"8 сердец. Призраки медленнее и слабее, бьют на 1. Фонарь и воздух тратятся на 20% медленнее. Для первого захода.",
	"6 сердец. Призраки и ресурсы без поблажек. Честная ночь: ошибка стоит крови, но не отнимает шанс.",
	"4 сердца. Призраки крепче и быстрее, бьют на 2. Фонарь и воздух садятся на 30% быстрее. Для тех, кто уже был здесь.",
]
const DIFFICULTY_BALANCE := [
	{  # ШАХТЁР
		"player_hp": 8, "enemy_hp_mult": 0.70, "speed_mult": 0.85,
		"enemy_damage": 1, "enemy_hp_bonus": 0, "aggro_mult": 0.80,
		"companion_damage": 5, "invuln_mult": 1.35,
		"lamp_drain_mult": 0.80, "air_drain_mult": 0.80, "attack_cd_mult": 1.20,
	},
	{  # СМЕНА
		"player_hp": 6, "enemy_hp_mult": 1.0, "speed_mult": 1.0,
		"enemy_damage": 1, "enemy_hp_bonus": 0, "aggro_mult": 1.0,
		"companion_damage": 3, "invuln_mult": 1.0,
		"lamp_drain_mult": 1.0, "air_drain_mult": 1.0, "attack_cd_mult": 1.0,
	},
	{  # ГЛУБИНА
		"player_hp": 4, "enemy_hp_mult": 1.55, "speed_mult": 1.15,
		"enemy_damage": 2, "enemy_hp_bonus": 1, "aggro_mult": 1.25,
		"companion_damage": 2, "invuln_mult": 0.75,
		"lamp_drain_mult": 1.30, "air_drain_mult": 1.30, "attack_cd_mult": 0.82,
	},
]
var max_hp: int = MAX_HP
var hp: int = MAX_HP
var difficulty: int = DIFF_NORMAL
var inventory: Array[String] = []
var notes: Array[Dictionary] = []
var flags: Dictionary = {}
var floor_index: int = 0
var spawn_id: String = "start"
var player_pos: Vector2 = Vector2.ZERO
var last_exit_kind: String = "lift"   ## "lift" или "stairs" — для карточки перехода
var zach_wait: bool = false
var zach_trust: int = 0
var ending: String = ""
var play_time: float = 0.0
var kills: int = 0
var deaths: int = 0
var hits_taken: int = 0
var lamp_charge: float = 100.0
var air: float = 100.0
var shift_start_time := 0.0
var shift_start_notes := 0
var shift_start_deaths := 0
var shift_start_hits := 0
var last_shift_report: Dictionary = {}
var best_rank := "—"
var best_time := 0.0
## Точки сохранения этажей: id этажа → [x, y]. Туда возвращает смерть.
var checkpoints: Dictionary = {}

var _save_dir: String = ""
var _is_dead: bool = false
var _in_game: bool = false

# --- сложность -------------------------------------------------------------

func difficulty_balance() -> Dictionary:
	return DIFFICULTY_BALANCE[clampi(difficulty, 0, DIFFICULTY_BALANCE.size() - 1)]


func difficulty_name() -> String:
	return DIFFICULTY_NAMES[clampi(difficulty, 0, DIFFICULTY_NAMES.size() - 1)]


func difficulty_desc() -> String:
	return DIFFICULTY_DESC[clampi(difficulty, 0, DIFFICULTY_DESC.size() - 1)]


## Выбор сложности из меню: доступен, пока идёт партия.
func set_difficulty(index: int) -> void:
	difficulty = clampi(index, 0, DIFFICULTY_NAMES.size() - 1)
	# в партии сразу подстраиваем максимальное здоровье под новый уровень
	if _in_game:
		max_hp = int(difficulty_balance()["player_hp"])
		hp = mini(hp, max_hp)
		hp_changed.emit()
	difficulty_changed.emit()


func in_game() -> bool:
	return _in_game


## Возврат в главное меню: сложность снова можно выбрать для новой партии.
func abandon_run() -> void:
	_in_game = false
	_is_dead = false
	difficulty_changed.emit()

# --- служебное -------------------------------------------------------------

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_load_records()


func _process(delta: float) -> void:
	play_time += delta


func _setup_input() -> void:
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_key("move_up", [KEY_W, KEY_UP])
	_key("move_down", [KEY_S, KEY_DOWN])
	_key("interact", [KEY_E, KEY_ENTER, KEY_KP_ENTER])
	_key("attack", [KEY_SPACE])
	_key("sprint", [KEY_SHIFT])
	_key("companion", [KEY_V])
	_key("inventory", [KEY_I, KEY_B])
	_key("map", [KEY_M])
	_key("journal", [KEY_J, KEY_TAB])
	_key("pause", [KEY_ESCAPE])
	_key("quick_save", [KEY_F5])
	_key("quick_load", [KEY_F9])
	_key("screenshot", [KEY_F2])
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	if InputMap.has_action("attack"):
		InputMap.action_add_event("attack", mb)


func _key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


# --- новая игра ------------------------------------------------------------

func new_game(diff: int = -1) -> void:
	if diff >= 0:
		difficulty = clampi(diff, 0, DIFFICULTY_NAMES.size() - 1)
	_in_game = true
	max_hp = int(difficulty_balance()["player_hp"])
	hp = max_hp
	inventory.clear()
	notes.clear()
	flags.clear()
	checkpoints.clear()
	floor_index = 0
	spawn_id = "start"
	player_pos = Vector2.ZERO
	zach_wait = false
	zach_trust = 0
	ending = ""
	play_time = 0.0
	kills = 0
	deaths = 0
	hits_taken = 0
	lamp_charge = MAX_LAMP
	air = MAX_AIR
	last_shift_report = {}
	_is_dead = false
	hp_changed.emit()
	lamp_changed.emit()
	air_changed.emit()
	inventory_changed.emit()
	notes_changed.emit()
	flags_changed.emit()
	difficulty_changed.emit()
	floor_changed.emit(floor_index)


# --- здоровье --------------------------------------------------------------

func damage(amount: int, _reason: String = "") -> void:
	if _is_dead or amount <= 0:
		return
	hp = maxi(0, hp - amount)
	hits_taken += 1
	hp_changed.emit()
	if hp <= 0:
		_is_dead = true
		deaths += 1
		player_died.emit()


func heal(amount: int) -> void:
	if amount <= 0:
		return
	hp = mini(max_hp, hp + amount)
	hp_changed.emit()


func revive_full() -> void:
	_is_dead = false
	max_hp = int(difficulty_balance()["player_hp"])
	hp = max_hp
	hp_changed.emit()


# --- точки сохранения и смерть ---------------------------------------------

func set_checkpoint(floor_id: String, pos: Vector2) -> void:
	if floor_id == "":
		return
	checkpoints[floor_id] = [pos.x, pos.y]


func checkpoint(floor_id: String) -> Vector2:
	var arr: Variant = checkpoints.get(floor_id, null)
	if arr is Array and (arr as Array).size() >= 2:
		return Vector2(float(arr[0]), float(arr[1]))
	return Vector2.ZERO


## Смерть возвращает к точке сохранения этажа, но не лечит: одно сердце, прогресс цел.
func revive_at_checkpoint() -> void:
	_is_dead = false
	hp = 1
	hp_changed.emit()


func is_dead() -> bool:
	return _is_dead


# --- лампа ---------------------------------------------------------------

func drain_lamp(amount: float) -> void:
	if amount <= 0.0 or _is_dead:
		return
	lamp_charge = maxf(0.0, lamp_charge - amount)
	lamp_changed.emit()


func add_lamp(amount: float) -> void:
	if amount <= 0.0:
		return
	lamp_charge = minf(MAX_LAMP, lamp_charge + amount)
	lamp_changed.emit()


func lamp_ratio() -> float:
	return clampf(lamp_charge / MAX_LAMP, 0.0, 1.0)


# --- итоги смены ----------------------------------------------------------

func begin_shift() -> void:
	shift_start_time = play_time
	shift_start_notes = notes.size()
	shift_start_deaths = deaths
	shift_start_hits = hits_taken


func finish_shift(contract: Dictionary) -> Dictionary:
	var elapsed := play_time - shift_start_time
	var found := notes.size() - shift_start_notes
	var no_death := deaths == shift_start_deaths
	var clean := hits_taken == shift_start_hits
	var time_ok := elapsed <= float(contract.get("time", 180.0))
	var notes_ok := found >= int(contract.get("notes", 2))
	var score := (1 if time_ok else 0) + (1 if notes_ok else 0) + (1 if no_death else 0) + (1 if clean else 0)
	var rank: String = ["C", "C", "B", "A", "S"][clampi(score, 0, 4)]
	var report := {
		"floor": str(contract.get("title", "СМЕНА")), "rank": rank, "time": elapsed,
		"notes": found, "notes_need": int(contract.get("notes", 2)),
		"time_ok": time_ok, "notes_ok": notes_ok, "no_death": no_death, "clean": clean,
	}
	last_shift_report = report
	var reward := ""
	match rank:
		"S":
			add_item("medkit")
			add_item("battery")
			reward = "аптечка + аккумулятор"
		"A":
			add_item("battery")
			reward = "аккумулятор"
		"B":
			add_item("vial")
			reward = "стимулятор"
	if reward != "":
		toast("Ранг %s. Награда: %s" % [rank, reward])
	else:
		toast("Ранг %s. Ночь закончена." % rank)
	_update_best(rank, elapsed)
	return report


func _rank_value(rank: String) -> int:
	return {"—": 0, "C": 1, "B": 2, "A": 3, "S": 4}.get(rank, 0)


## Рекорд хранится отдельно от партии, чтобы был смысл переигрывать.
func _update_best(rank: String, elapsed: float) -> void:
	var changed := false
	if _rank_value(rank) > _rank_value(best_rank):
		best_rank = rank
		best_time = elapsed
		changed = true
	elif rank == best_rank and (best_time <= 0.0 or elapsed < best_time):
		best_time = elapsed
		changed = true
	if changed:
		_save_records()


func _load_records() -> void:
	var path := save_dir() + "/records.json"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if d is Dictionary:
		best_rank = str(d.get("best_rank", "—"))
		best_time = float(d.get("best_time", 0.0))


func _save_records() -> void:
	var f := FileAccess.open(save_dir() + "/records.json", FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"best_rank": best_rank, "best_time": best_time}, "	"))
	f.close()


func rank_line() -> String:
	if best_rank == "—":
		return "Рекорд ночи: пока нет"
	return "Рекорд ночи: %s · %s" % [best_rank, _fmt_time(best_time)]


func _fmt_time(seconds: float) -> String:
	var t := int(seconds)
	return "%02d:%02d" % [t / 60, t % 60]


func drain_air(amount: float) -> void:
	if amount <= 0.0 or _is_dead:
		return
	air = maxf(0.0, air - amount)
	air_changed.emit()


func add_air(amount: float) -> void:
	if amount <= 0.0:
		return
	air = minf(MAX_AIR, air + amount)
	air_changed.emit()


func air_ratio() -> float:
	return clampf(air / MAX_AIR, 0.0, 1.0)


# --- инвентарь -------------------------------------------------------------

func has_item(id: String) -> bool:
	return inventory.has(id)


func add_item(id: String) -> bool:
	if inventory.has(id):
		return false
	inventory.append(id)
	inventory_changed.emit()
	return true


func remove_item(id: String) -> bool:
	var idx := inventory.find(id)
	if idx == -1:
		return false
	inventory.remove_at(idx)
	inventory_changed.emit()
	return true


func item_count() -> int:
	return inventory.size()


# --- журнал записок --------------------------------------------------------

func add_note(title: String, body: String) -> bool:
	for n in notes:
		if str(n.get("title", "")) == title:
			return false
	notes.append({"title": title, "body": body})
	notes_changed.emit()
	return true


func has_note(title: String) -> bool:
	for n in notes:
		if str(n.get("title", "")) == title:
			return true
	return false


# --- флаги -----------------------------------------------------------------

func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value
	flags_changed.emit()


func get_flag(key: String, default_value: Variant = false) -> Variant:
	return flags.get(key, default_value)


func flag(key: String) -> bool:
	return bool(flags.get(key, false))


func add_counter(key: String, amount: int = 1) -> int:
	var v := int(flags.get(key, 0)) + amount
	flags[key] = v
	flags_changed.emit()
	return v


func counter(key: String) -> int:
	return int(flags.get(key, 0))


# --- этажи -----------------------------------------------------------------

func set_floor(index: int, spawn: String = "start") -> void:
	floor_index = clampi(index, 0, 0)
	spawn_id = spawn
	floor_changed.emit(floor_index)


func floor_id() -> String:
	return "KORPUS_B"


# --- сообщения -------------------------------------------------------------

func toast(text: String) -> void:
	toast_requested.emit(text)


# --- сохранения ------------------------------------------------------------

func save_dir() -> String:
	if _save_dir != "":
		return _save_dir
	for cand in ["res://saves", "user://saves"]:
		var abs_path := ProjectSettings.globalize_path(cand)
		var err := DirAccess.make_dir_recursive_absolute(abs_path)
		if err == OK or err == ERR_ALREADY_EXISTS or DirAccess.dir_exists_absolute(abs_path):
			var probe := FileAccess.open(cand + "/probe.tmp", FileAccess.WRITE)
			if probe != null:
				probe.close()
				DirAccess.remove_absolute(ProjectSettings.globalize_path(cand + "/probe.tmp"))
				_save_dir = cand
				return _save_dir
	_save_dir = "user://"
	return _save_dir


func save_path() -> String:
	return save_dir() + "/" + SAVE_NAME


func has_save() -> bool:
	return FileAccess.file_exists(save_path())


func save_game() -> bool:
	var data := {
		"version": 1,
		"hp": hp,
		"max_hp": max_hp,
		"difficulty": difficulty,
		"lamp_charge": lamp_charge,
		"air": air,
		"inventory": inventory,
		"notes": notes,
		"flags": flags,
		"floor_index": floor_index,
		"spawn_id": spawn_id,
		"player_pos": [player_pos.x, player_pos.y],
		"zach_wait": zach_wait,
		"zach_trust": zach_trust,
		"ending": ending,
		"play_time": play_time,
		"kills": kills,
		"deaths": deaths,
		"hits_taken": hits_taken,
		"checkpoints": checkpoints,
	}
	var f := FileAccess.open(save_path(), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(save_path(), FileAccess.READ)
	if f == null:
		return false
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = parsed
	difficulty = clampi(int(d.get("difficulty", DIFF_NORMAL)), 0, DIFFICULTY_NAMES.size() - 1)
	_in_game = true
	max_hp = int(difficulty_balance()["player_hp"])
	hp = mini(int(d.get("hp", max_hp)), max_hp)
	lamp_charge = clampf(float(d.get("lamp_charge", MAX_LAMP)), 0.0, MAX_LAMP)
	air = clampf(float(d.get("air", MAX_AIR)), 0.0, MAX_AIR)
	inventory.clear()
	for it in d.get("inventory", []):
		inventory.append(str(it))
	notes.clear()
	for n in d.get("notes", []):
		if typeof(n) == TYPE_DICTIONARY:
			notes.append({"title": str(n.get("title", "")), "body": str(n.get("body", ""))})
	flags = d.get("flags", {})
	floor_index = clampi(int(d.get("floor_index", 0)), 0, 0)
	spawn_id = str(d.get("spawn_id", "start"))
	var pp: Array = d.get("player_pos", [0.0, 0.0])
	if pp.size() >= 2:
		player_pos = Vector2(float(pp[0]), float(pp[1]))
	zach_wait = bool(d.get("zach_wait", false))
	zach_trust = int(d.get("zach_trust", 0))
	ending = str(d.get("ending", ""))
	play_time = float(d.get("play_time", 0.0))
	kills = int(d.get("kills", 0))
	deaths = int(d.get("deaths", 0))
	hits_taken = int(d.get("hits_taken", 0))
	checkpoints.clear()
	var cps: Variant = d.get("checkpoints", {})
	if cps is Dictionary:
		for k in (cps as Dictionary).keys():
			checkpoints[str(k)] = (cps as Dictionary)[k]
	_is_dead = false
	hp_changed.emit()
	lamp_changed.emit()
	air_changed.emit()
	inventory_changed.emit()
	notes_changed.emit()
	flags_changed.emit()
	difficulty_changed.emit()
	floor_changed.emit(floor_index)
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path()))


func format_time() -> String:
	var t := int(play_time)
	return "%02d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]



