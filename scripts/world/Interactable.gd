class_name Interactable
extends Area2D
## Универсальный объект взаимодействия: предмет, записка, дверь, сейф, НПС,
## могила, свеча, алтарь, выход, точка сохранения. Логика задаётся данными.

const DOOR_SWING_TIME := 0.35   ## секунды на поворот створки

var world: Node = null
var data: Dictionary = {}
var kind := "pickup"
var available := true

var marker: Sprite2D = null
var glow: PointLight2D = null
var panel: Sprite2D = null
var _dug := false
var _lit := false
var _open := false
var _blocker: StaticBody2D = null
var _door_sprite: Sprite2D = null
var _blocker_shape: CollisionShape2D = null
var _leaf: Sprite2D = null
var _leaves: Array = []
var _leaf_standing := false
var _leaf_open_angle := 0.0
var _glow_tween: Tween = null
var _door_tween: Tween = null
var _geom: DoorGeom = null


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("interactables")

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 30.0
	shape.shape = circle
	add_child(shape)

	var fid := _fid()
	_dug = Game.flag("dug:%s" % fid)
	_lit = Game.flag("lit:%s" % fid)
	_open = Game.flag("opened:%s" % fid)
	_build_visual()


func _fid() -> String:
	return "%s:%d:%d" % [str(data.get("_floor", "?")), int(data.get("x", 0)), int(data.get("y", 0))]


# --- визуал ----------------------------------------------------------------

func _build_visual() -> void:
	match kind:
		"pickup", "note", "lore":
			_add_item_marker()
		"keypad":
			panel = Sprite2D.new()
			panel.texture = Tex.solid(16, 12, Color(0.16, 0.18, 0.22))
			panel.position = Vector2(0, -14)
			add_child(panel)
			var screen := Sprite2D.new()
			screen.texture = Tex.solid(8, 4, Color(0.75, 0.25, 0.2))
			screen.position = Vector2(0, -16)
			add_child(screen)
			_add_glow(Color(1.0, 0.4, 0.3), 0.35, 60)
		"npc":
			var sp := Sprite2D.new()
			sp.texture = Art.npc_sprite(str(data.get("who", "")))
			sp.scale = Vector2(0.36, 0.36)
			sp.position = Vector2(0, -22)
			add_child(sp)
			var sh := Sprite2D.new()
			sh.texture = Tex.shadow_texture(30, 13)
			sh.position = Vector2(0, -1)
			add_child(sh)
			_add_glow(Color(1.0, 0.85, 0.7), 0.28, 90)
		"grave":
			_add_sigil_marker(str(data.get("sigil", "")))
			_add_glow(Color(0.55, 0.6, 0.8), 0.22, 70)
		"candle":
			_add_sigil_marker(str(data.get("sigil", "")))
			_set_flame(_lit)
		"altar":
			_add_glow(Color(1.0, 0.85, 0.6), 0.5, 150)
		"switch":
			var box := Sprite2D.new()
			box.texture = Tex.solid(18, 22, Color(0.20, 0.22, 0.20))
			box.position = Vector2(0, -16)
			add_child(box)
			var lever := Sprite2D.new()
			lever.texture = Art.icon("lever")
			lever.scale = Vector2(0.4, 0.4)
			lever.position = Vector2(0, -18)
			add_child(lever)
			_add_glow(Color(0.7, 0.95, 0.6), 0.28, 60)
		"finale":
			var gate := Sprite2D.new()
			gate.texture = Art.ui("lift_doors")
			gate.scale = Vector2(0.72, 0.72)
			gate.position = Vector2(0, -30)
			add_child(gate)
			_add_glow(Color(0.85, 0.75, 0.55), 0.4, 150)
		"exit":
			if str(data.get("style", "")) == "stairs":
				_build_stairs()
			else:
				var lift := Sprite2D.new()
				lift.texture = Art.ui("lift_doors")
				lift.scale = Vector2(0.62, 0.62)
				lift.position = Vector2(0, -28)
				add_child(lift)
				_add_glow(Color(1.0, 0.7, 0.35), 0.55, 170)
		"save":
			_add_glow(Color(0.7, 0.85, 1.0), 0.3, 80)
			_add_item_marker("note")
		"door":
			_build_door()
		_:
			pass


## Лестничный марш в духе Hotline Miami: спуск вниз, подсвеченный проём.
func _build_stairs() -> void:
	var down := str(data.get("dir", "down")) != "up"
	var sp := Sprite2D.new()
	sp.texture = Tex.stairs_texture(down)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.position = Vector2(0, -20)
	add_child(sp)

	# тёмная площадка под маршем, чтобы он не «висел» на полу
	var pad := Sprite2D.new()
	pad.texture = Tex.solid(58, 26, Color(0.01, 0.012, 0.015, 0.55))
	pad.position = Vector2(0, 3)
	pad.z_index = -1
	add_child(pad)
	_add_glow(Color(1.0, 0.74, 0.40), 0.42, 120)


## Дверь: порог и косяки стоят на месте, створка висит на петле и поворачивается,
## а преграда на весь проход не удаляется, а выключается — дверь можно закрыть.
## Узкая квадратная створка при открытии встаёт ребром к игроку (в проекции сужается
## к косяку), высокая — распахивается в плоскости пола, как обычная дверь.
func _build_door() -> void:
	var map: Array = world.map if world != null and is_instance_valid(world) else []
	_geom = DoorGeom.create(map, data)
	position = _geom.center
	var gw := maxi(4, int(_geom.gap_px().x))
	var gh := maxi(4, int(_geom.gap_px().y))
	var bars := _door_bars()

	# нижний слой: пол за порогом
	var floor_sp := Sprite2D.new()
	floor_sp.texture = Doors.floor_texture(_theme(), gw, gh, _geom.vertical)
	floor_sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(floor_sp)

	# створка одна, холст ровно с проём — панель не вылезает за блок кладки.
	# Петля у высокой двери — верхний косяк (створка уходит от стены вбок),
	# у квадратной — нижний угол (створка доворачивается ребром).
	_leaf_standing = not _geom.tall()
	var leaf_tex := Doors.leaf_texture(_theme(), gw, gh, _geom.vertical, false, bars)
	var leaf_px := Doors.leaf_size(gw, gh, _geom.vertical, false)
	var leaf := Sprite2D.new()
	leaf.texture = leaf_tex
	leaf.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _leaf_standing:
		var hinge_right := _swing_sign() < 0.0
		leaf.position = Vector2((float(gw) * 0.5) if hinge_right else (-float(gw) * 0.5),
			float(gh) * 0.5)
		leaf.offset = Vector2((-float(leaf_px.x) * 0.5) if hinge_right else (float(leaf_px.x) * 0.5),
			-float(leaf_px.y) * 0.5)
		leaf.flip_h = hinge_right
	else:
		leaf.position = Vector2(0.0, -float(gh) * 0.5)
		leaf.offset = Vector2(0.0, float(leaf_px.y) * 0.5)
		_leaf_open_angle = deg_to_rad(90.0) * (1.0 if _geom.open_dir.x < 0 else -1.0)
	add_child(leaf)
	_leaves.append(leaf)
	_leaf = leaf
	var sh := Sprite2D.new()
	sh.texture = Tex.shadow_texture(maxi(10, gw - 2), 9)
	sh.position = Vector2(0, float(gh) * 0.5 - 3)
	sh.modulate = Color(1, 1, 1, 0.65)
	add_child(sh)
	move_child(sh, floor_sp.get_index() + 1)

	# верхний слой: косяки поверх полотна
	var frame_sp := Sprite2D.new()
	frame_sp.texture = Doors.frame_texture(_theme(), gw, gh, _geom.vertical)
	frame_sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(frame_sp)
	_door_sprite = frame_sp

	# подпись на створке (бирка «B5-МОРГ» и вроде того) — висит на полотне
	if maxi(gw, gh) >= 64 or _leaf_standing:
		_add_door_sign()

	_blocker = StaticBody2D.new()
	_blocker.collision_layer = 1
	_blocker.collision_mask = 0
	_blocker_shape = CollisionShape2D.new()
	# геометрия двери хранится в тайлах, а позиция узла — в пикселях: переводим всё в px
	var blk_pos := Vector2(_geom.blocker.position) * float(World.TILE)
	var blk_size := Vector2(_geom.blocker.size) * float(World.TILE)
	var rs := RectangleShape2D.new()
	rs.size = blk_size
	_blocker_shape.shape = rs
	_blocker_shape.position = blk_pos + blk_size * 0.5 - position
	_blocker.add_child(_blocker_shape)
	add_child(_blocker)

	if _open:
		_apply_door_state(false)
		return
	_add_glow(Color(1.0, 0.55, 0.35), 0.22, 70, Vector2.ZERO)


## Решётка вместо полотна: у дробилки всегда, у отвала и диспетчерской — по полю "bars".
func _door_bars() -> bool:
	return bool(data.get("bars", false)) or _theme() == "prison"


## Куда доворачиваются створки: +1 — по часовой, -1 — против. По умолчанию полотно
## уходит в ту сторону, куда ведёт проход (туда протянута преграда). Поле данных
## "swing" (+1 / -1) задаёт сторону вручную.
func _swing_sign() -> float:
	var hinted := float(data.get("swing", 0.0))
	if not is_zero_approx(hinted):
		return signf(hinted)
	if _geom.vertical:
		return 1.0 if _geom.blocker.position.x < _geom.gap.position.x else -1.0
	return 1.0 if _geom.blocker.position.y + _geom.blocker.size.y > _geom.gap.position.y + _geom.gap.size.y else -1.0


## Металлическая бирка на створке — едет вместе с полотном.
func _add_door_sign() -> void:
	var gap := _geom.gap_px()
	var w := clampi(int(float(gap.x) * 0.6), 8, 40)
	var sign := Sprite2D.new()
	sign.texture = Tex.solid(w, 4, Color(0.50, 0.48, 0.42))
	if _leaf != null:
		# бирка висит на створке выше середины панели
		sign.position = _leaf.offset + Vector2(0.0, -float(gap.y) * 0.28)
		_leaf.add_child(sign)
	else:
		sign.position = Vector2(0.0, -float(gap.y) * 0.28)
		add_child(sign)


func _theme() -> String:
	if world != null and is_instance_valid(world):
		return str(world.level.get("theme", "hospital"))
	return "hospital"


func _add_item_marker(icon_id: String = "") -> void:
	var id := icon_id
	if id == "":
		id = str(Items.get_item(str(data.get("item", "note"))).get("icon", "note"))
	marker = Sprite2D.new()
	marker.texture = Art.icon(id)
	marker.scale = Vector2(0.42, 0.42)
	marker.position = Vector2(0, -12)
	add_child(marker)
	var bob := create_tween()
	bob.set_loops()
	bob.tween_property(marker, "position:y", -16.0, 1.4).set_trans(Tween.TRANS_SINE)
	bob.tween_property(marker, "position:y", -11.0, 1.4).set_trans(Tween.TRANS_SINE)
	_add_glow(Color(1.0, 0.9, 0.7), 0.35, 70)


func _add_sigil_marker(sigil: String) -> void:
	if sigil == "":
		return
	marker = Sprite2D.new()
	marker.texture = Art.ui("sigil_" + sigil)
	marker.scale = Vector2(0.5, 0.5)
	marker.position = Vector2(0, -30)
	marker.modulate = Color(0.55, 0.55, 0.6) if kind == "grave" else Color(0.85, 0.8, 0.7)
	add_child(marker)


func _add_glow(color: Color, energy: float, radius: float, offset: Vector2 = Vector2(0, -12)) -> void:
	glow = PointLight2D.new()
	glow.texture = Tex.light_texture(256, 2.6)
	glow.color = color
	glow.energy = energy
	glow.texture_scale = radius / 128.0
	glow.position = offset
	add_child(glow)
	_add_flicker()


func _add_flicker() -> void:
	if glow == null:
		return
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow_tween = create_tween()
	_glow_tween.set_loops()
	var e := glow.energy
	_glow_tween.tween_property(glow, "energy", e * 1.25, randf_range(0.7, 1.4))
	_glow_tween.tween_property(glow, "energy", e * 0.8, randf_range(0.7, 1.4))


## Гасит свечение вместе с его миганием: без этого бесконечный tween остаётся
## ссылаться на удалённый узел, движок ловит «infinite loop» и сыпет ошибками
## на каждом кадре — в браузере это выглядит как подвисание игры.
func _kill_glow() -> void:
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow_tween = null
	if glow != null and is_instance_valid(glow):
		glow.queue_free()
	glow = null


func _set_flame(show: bool) -> void:
	if show:
		if marker == null:
			marker = Sprite2D.new()
			marker.texture = Art.icon("candle")
			marker.scale = Vector2(0.4, 0.4)
			marker.position = Vector2(0, -30)
			add_child(marker)
		marker.modulate = Color(1.3, 1.1, 0.7)
		if glow == null:
			_add_glow(Color(1.0, 0.75, 0.4), 0.75, 130)
		else:
			glow.energy = 0.75
	else:
		if glow == null:
			_add_glow(Color(0.4, 0.35, 0.4), 0.12, 50)
		else:
			glow.energy = 0.12


# --- взаимодействие --------------------------------------------------------

func prompt_text() -> String:
	match kind:
		"pickup":
			return "Взять: %s" % Items.name_of(str(data.get("item", "note")))
		"note":
			return "Прочитать: %s" % str(data.get("title", "записка"))
		"lore":
			return "Осмотреть: %s" % str(data.get("title", "..."))
		"keypad":
			return "Ввести код: %s" % str(data.get("label", "сейф"))
		"npc":
			return "Говорить"
		"grave":
			return "Вскрыть знак" if not _dug else "Знак уже вскрыт"
		"candle":
			return "Зажечь лампу" if not _lit else "Лампа горит"
		"altar":
			return str(data.get("label", "Алтарь"))
		"switch":
			return str(data.get("label", "Щиток"))
		"finale":
			return str(data.get("label", "Выход"))
		"exit":
			return str(data.get("label", "Выход"))
		"door":
			var door_label := str(data.get("label", "Дверь"))
			return ("Закрыть: %s" % door_label) if _open else door_label
		"save":
			return "Сохранить: %s" % str(data.get("label", "журнал"))
	return "Осмотреть"


func interact(_player: Node) -> void:
	match kind:
		"pickup":
			_do_pickup()
		"note", "lore":
			_do_read()
		"keypad":
			_do_keypad()
		"npc":
			_do_talk()
		"grave":
			_do_dig()
		"candle":
			_do_light()
		"altar":
			_do_altar()
		"switch":
			_do_switch()
		"finale":
			_do_finale()
		"exit":
			_do_exit()
		"door":
			_do_door()
		"save":
			_do_save()


func _do_pickup() -> void:
	var item := str(data.get("item", "note"))
	Game.add_item(item)
	Game.set_flag("picked:%s" % _fid())
	Audio.play("pickup", -4.0)
	Game.toast("Получено: %s" % Items.name_of(item))
	available = false
	world.spawn_pickup_effect(global_position)
	var act := str(data.get("action", ""))
	if act != "" and world != null:
		world.handle_action(act)
	queue_free()


func _do_read() -> void:
	var title := str(data.get("title", "Записка"))
	var body := str(data.get("body", ""))
	Game.add_note(title, body)
	Game.set_flag("read:%s" % _fid())
	var extra := str(data.get("flag", ""))
	if extra != "":
		Game.set_flag(extra)
	if bool(data.get("story", false)):
		var n := Game.add_counter("story_notes")
		if n >= 6:
			Game.set_flag("all_notes")
	Audio.play("note", -4.0)
	world.show_note(title, body)


func _do_talk() -> void:
	var dlg := str(data.get("dialog", ""))
	var alt_flag := str(data.get("alt_flag", ""))
	if alt_flag != "" and Game.flag(alt_flag):
		dlg = str(data.get("alt_dialog", dlg))
	# знание открывает другой разговор: комиссия Зои начинается только после рапорта
	var by_flag: Dictionary = data.get("flag_dialog", {})
	for k in by_flag.keys():
		if Game.flag(str(k)):
			dlg = str(by_flag[k])
			break
	# диалог, который открывается, если в руках есть нужный предмет
	var id_map: Dictionary = data.get("item_dialog", {})
	for k in id_map.keys():
		if Game.has_item(str(k)):
			dlg = str(id_map[k])
			break
	if dlg != "":
		world.show_dialog(dlg)


## Панель с кодом: пока игрок не добыл знание, панель даже не включается.
func _do_keypad() -> void:
	var missing := _missing_knowledge()
	if missing != "":
		Audio.play("deny", -4.0)
		var dlg := str(data.get("locked_dialog", ""))
		if dlg != "":
			world.show_dialog(dlg)
		else:
			Game.toast(str(data.get("locked", "Ты ещё не знаешь код.")))
		return
	world.ask_code(self)


## Флаги знаний, которых не хватает для ввода кода (requires_flag / requires_flags).
func _missing_knowledge() -> String:
	var need: Array = []
	var multi: Variant = data.get("requires_flags", [])
	if multi is Array:
		need.append_array(multi)
	var one := str(data.get("requires_flag", ""))
	if one != "":
		need.append(one)
	for f in need:
		if not Game.flag(str(f)):
			return str(f)
	return ""


## Наказание за небрежность: испытание хозяина этажа не прощает ошибок.
func _punish() -> void:
	var action := str(data.get("penalty_action", ""))
	if action != "" and world != null:
		world.handle_action(action)
	var dmg := int(data.get("penalty_damage", 0))
	if dmg > 0 and world != null and world.player != null:
		world.player.hurt(dmg, world.player.global_position)


func _do_dig() -> void:
	if _dug:
		Game.toast("Здесь уже пусто.")
		return
	if not Game.has_item("shovel"):
		Audio.play("deny", -4.0)
		Game.toast("Нужна лопата. Она где-то в сарае.")
		return
	var order := int(data.get("order", 0))
	var have := Game.counter("b4_dig")
	if order == have + 1:
		Game.add_counter("b4_dig")
		Game.set_flag("dug:%s" % _fid())
		_dug = true
		Audio.play("dig", -3.0)
		world.on_grave_dug(self, have + 1)
	else:
		world.show_dialog("b4_wrong_grave")


func _do_light() -> void:
	if _lit:
		return
	var order := int(data.get("order", 0))
	var have := Game.counter("b2_candles")
	if order == have + 1:
		Game.add_counter("b2_candles")
		Game.set_flag("lit:%s" % _fid())
		_lit = true
		_set_flame(true)
		Audio.play("candle", -4.0)
		world.on_candle_lit(have + 1)
	else:
		world.show_dialog("b2_wrong_candle")


func _do_altar() -> void:
	var need_item := str(data.get("requires_item", ""))
	if need_item != "" and not Game.has_item(need_item):
		Audio.play("deny", -4.0)
		var item_dlg := str(data.get("item_blocked_dialog", ""))
		if item_dlg != "":
			world.show_dialog(item_dlg)
		else:
			Game.toast(str(data.get("item_blocked", "Не хватает предмета.")))
		return
	var need := str(data.get("requires_flag", ""))
	if need == "" or Game.flag(need):
		world.show_dialog(str(data.get("dialog", "")))
	else:
		world.show_dialog(str(data.get("blocked_dialog", "")))


## Щиток: вставляем предохранитель и включаем питание входа.
func _do_switch() -> void:
	if Game.flag("power"):
		Game.toast("Питание уже включено.")
		return
	var need_item := str(data.get("requires_item", ""))
	if need_item != "" and not Game.has_item(need_item):
		Audio.play("deny", -4.0)
		var item_dlg := str(data.get("item_blocked_dialog", ""))
		if item_dlg != "":
			world.show_dialog(item_dlg)
		else:
			Game.toast(str(data.get("item_blocked", "Не хватает предмета.")))
		return
	var act := str(data.get("action", ""))
	if act != "":
		world.handle_action(act)
	var dlg := str(data.get("dialog", ""))
	if dlg != "":
		world.show_dialog(dlg)
	else:
		Game.toast("Готово.")


## Выход из корпуса: проверяет ключ и питание и открывает финальный разговор.
func _do_finale() -> void:
	var need_item := str(data.get("requires_item", ""))
	if need_item != "" and not Game.has_item(need_item):
		Audio.play("door_locked", -4.0)
		var bd0 := str(data.get("blocked_dialog", ""))
		if bd0 != "":
			world.show_dialog(bd0)
		else:
			Game.toast(str(data.get("blocked", "Заперто.")))
		return
	var need_flag := str(data.get("requires_flag", ""))
	if need_flag != "" and not Game.flag(need_flag):
		Audio.play("door_locked", -4.0)
		var bd := str(data.get("blocked_dialog", ""))
		if bd != "":
			world.show_dialog(bd)
		else:
			Game.toast(str(data.get("blocked", "Заперто.")))
		return
	var dlg := str(data.get("dialog", "final"))
	var alt_flag := str(data.get("alt_flag", ""))
	if alt_flag != "" and Game.flag(alt_flag):
		dlg = str(data.get("alt_dialog", dlg))
	Audio.play("door", -3.0)
	world.show_dialog(dlg)


func _do_exit() -> void:
	var need_item := str(data.get("requires_item", ""))
	if need_item != "" and not Game.has_item(need_item):
		Audio.play("door_locked", -4.0)
		Game.toast(str(data.get("blocked", "Заперто.")))
		return
	var need_flag := str(data.get("requires_flag", ""))
	if need_flag != "" and not Game.flag(need_flag):
		Audio.play("door_locked", -4.0)
		var bd := str(data.get("dialog", ""))
		if bd != "":
			world.show_dialog(bd)
		else:
			Game.toast(str(data.get("blocked", "Заперто.")))
		return
	var use_flag := str(data.get("flag_on_use", ""))
	if use_flag != "" and not Game.flag(use_flag):
		var dlg := str(data.get("dialog", ""))
		if dlg != "":
			world.show_dialog(dlg)
			return
		Game.set_flag(use_flag)
	Audio.play("door", -3.0)
	Game.last_exit_kind = "stairs" if str(data.get("style", "")) == "stairs" else "lift"
	world.leave_floor(int(data.get("target_floor", 0)))


func _do_save() -> void:
	# точка сохранения этажа = точка возрождения после смерти
	Game.set_checkpoint(str(data.get("_floor", "")), global_position)
	if Game.save_game():
		Audio.play("save", -3.0)
		Game.toast("Игра сохранена. %s" % Game.format_time())
	else:
		Game.toast("Не удалось сохранить игру.")


## Дверь: открывается ключом или знанием, а открытую можно снова закрыть.
func _do_door() -> void:
	if _open:
		set_door_open(false)
		return
	var need_item := str(data.get("requires_item", ""))
	if need_item != "" and not Game.has_item(need_item):
		_refuse_locked()
		return
	var need_flag := str(data.get("requires_flag", ""))
	if need_flag != "" and not Game.flag(need_flag):
		_refuse_locked()
		return
	set_door_open(true, true)


## Приводит створку и преграду к состоянию _open. animate = false — мгновенно
## (загрузка этажа, дверь уже была открыта). Квадратная створка поворачивается на петле
## и встаёт ребром (сужается к косяку), высокая — доворачивается в плоскости пола.
func _apply_door_state(animate: bool) -> void:
	if _blocker_shape != null:
		_blocker_shape.set_deferred("disabled", _open)
	if _leaves.is_empty():
		return
	if _door_tween != null and _door_tween.is_valid():
		_door_tween.kill()
	var prop := "scale" if _leaf_standing else "rotation"
	var target: Variant = Vector2(Doors.OPEN_SCALE, 1.0) if _open else Vector2.ONE
	if not _leaf_standing:
		target = _leaf_open_angle if _open else 0.0
	for i in _leaves.size():
		var leaf: Sprite2D = _leaves[i]
		if not animate:
			leaf.set(prop, target)
			continue
		if i == 0:
			_door_tween = create_tween()
			_door_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_door_tween.tween_property(leaf, prop, target, DOOR_SWING_TIME)
		else:
			_door_tween.parallel().tween_property(leaf, prop, target, DOOR_SWING_TIME)


## Открыть или закрыть дверь. Проход освобождается сразу, створка доворачивает.
func set_door_open(open: bool, announce: bool = false) -> void:
	if _open == open:
		return
	_open = open
	Game.set_flag("opened:%s" % _fid(), open)
	_apply_door_state(true)
	if open:
		_kill_glow()
		Audio.play("door", -3.0)
		if announce:
			Game.toast("%s — открыто." % str(data.get("label", "Дверь")))
	else:
		Audio.play("door", -4.0)


func _refuse_locked() -> void:
	Audio.play("door_locked", -4.0)
	var dlg := str(data.get("locked_dialog", ""))
	if dlg != "" and world != null:
		world.show_dialog(dlg)
	else:
		Game.toast(str(data.get("locked", "Заперто.")))


## Открывает дверь (совместимость со старым API и скриптовыми событиями).
func open_door(announce: bool = false) -> void:
	set_door_open(true, announce)


func is_open() -> bool:
	return _open


## Перекрывает ли дверь проход прямо сейчас (для тестов и отладки).
func is_blocking() -> bool:
	return _blocker_shape != null and is_instance_valid(_blocker_shape) and not _blocker_shape.disabled


func submit_code(text: String) -> bool:
	var ok := text == str(data.get("code", ""))
	if ok:
		Game.set_flag(str(data.get("flag", "code_ok")))
		var reward := str(data.get("reward", ""))
		if reward != "":
			Game.add_item(reward)
			Game.toast("Получено: %s" % Items.name_of(reward))
		Audio.play("beep", -3.0)
		available = false
		if glow != null:
			glow.color = Color(0.4, 1.0, 0.5)
		var act := str(data.get("action", ""))
		if act != "" and world != null:
			world.handle_action(act)
	else:
		Audio.play("deny", -4.0)
		Game.toast("Неверный код.")
		_punish()
	return ok


func set_candle_out() -> void:
	_lit = false
	Game.set_flag("lit:%s" % _fid(), false)
	if marker != null:
		marker.modulate = Color(0.5, 0.5, 0.55)
	if glow != null:
		glow.energy = 0.12


## Ошибка у Тихона: выработка снова смыкается, знак можно вскрыть заново.
func reset_dug() -> void:
	_dug = false
	Game.set_flag("dug:%s" % _fid(), false)

