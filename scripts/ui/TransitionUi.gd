class_name TransitionUi
extends Control
## Короткая карточка между горизонтами в духе Hotline Miami:
## ранг закрытой смены, следующий этаж и лифт. Не блокирует управление.

var _panel: PanelContainer
var _rank: Label
var _rank_caption: Label
var _floor: Label
var _info: Label
var _tasks: Label
var _route: Label
var _token := 0


func _ready() -> void:
	UiTheme.fullscreen(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	UiTheme.fullscreen(dim)
	dim.color = Color(0.01, 0.012, 0.012, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_panel = UiTheme.make_panel(Color(0.035, 0.045, 0.043, 0.97), UiTheme.BORDER_HOT, 2)
	_panel.position = Vector2(230, 132)
	_panel.custom_minimum_size = Vector2(820, 456)
	_panel.size = Vector2(820, 456)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)

	var top := UiTheme.make_label("НОЧЬ ЗАКРЫТА", 16, UiTheme.DIM)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top)

	_rank = UiTheme.make_label("S", 88, UiTheme.GOLD)
	_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_rank)

	_rank_caption = UiTheme.make_label("РАНГ", 14, UiTheme.DIM)
	_rank_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_rank_caption)

	_floor = UiTheme.make_label("", 24, UiTheme.TEXT)
	_floor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_floor.custom_minimum_size = Vector2(760, 40)
	_floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_floor)

	_info = UiTheme.make_label("", 15, UiTheme.DIM)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_info)

	_tasks = UiTheme.make_label("", 14, UiTheme.DIM)
	_tasks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tasks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tasks.custom_minimum_size = Vector2(700, 48)
	_tasks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_tasks)

	_route = UiTheme.make_label("ЛИФТ ИДЁТ ВНИЗ", 13, UiTheme.ACCENT)
	_route.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_route.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_route)


func show_report(report: Dictionary, target: int) -> void:
	if report.is_empty():
		return
	_token += 1
	var token := _token
	var rank := str(report.get("rank", "—"))
	_rank.text = rank
	_rank.add_theme_color_override("font_color", _rank_color(rank))
	_rank_caption.text = "РАНГ НОЧИ"
	var cur := clampi(target - 1, 0, Levels.count() - 1)
	_floor.text = "%s   →   %s" % [Levels.floor_name(cur), Levels.floor_name(target)]
	_info.text = "%s · %s · записей %d/%d" % [
		str(report.get("floor", "СМЕНА")),
		_fmt(float(report.get("time", 0.0))),
		int(report.get("notes", 0)), int(report.get("notes_need", 0)),
	]
	_tasks.text = "ВРЕМЯ: %s   ·   ЗАПИСИ: %s   ·   БЕЗ СМЕРТЕЙ: %s   ·   БЕЗ УРОНА: %s" % [
		_mark(bool(report.get("time_ok", false))),
		_mark(bool(report.get("notes_ok", false))),
		_mark(bool(report.get("no_death", false))),
		_mark(bool(report.get("clean", false))),
	]
	_route.text = "ЛЕСТНИЦА ВНИЗ" if Game.last_exit_kind == "stairs" else "ЛИФТ ИДЁТ ВНИЗ"
	visible = true
	modulate.a = 0.0
	var in_t := create_tween()
	in_t.tween_property(self, "modulate:a", 1.0, 0.18)
	await get_tree().create_timer(1.55, true, false, true).timeout
	if token != _token or not visible:
		return
	var out_t := create_tween()
	out_t.tween_property(self, "modulate:a", 0.0, 0.35)
	out_t.tween_callback(func() -> void:
		if token == _token:
			visible = false)


func _mark(ok: bool) -> String:
	return "✓" if ok else "—"


func _rank_color(rank: String) -> Color:
	match rank:
		"S":
			return Color(0.96, 0.79, 0.35)
		"A":
			return Color(0.78, 0.88, 0.78)
		"B":
			return Color(0.62, 0.68, 0.66)
		_:
			return Color(0.72, 0.34, 0.27)


func _fmt(seconds: float) -> String:
	var t := int(seconds)
	return "%02d:%02d" % [t / 60, t % 60]
