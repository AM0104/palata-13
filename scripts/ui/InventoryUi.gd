class_name InventoryUi
extends Control
## Инвентарь и журнал: сетка предметов, описание, применение, список записок.

signal closed

var _panel: PanelContainer
var _items_view: HBoxContainer
var _journal_view: HBoxContainer
var _grid: GridContainer
var _preview: TextureRect
var _name_label: Label
var _desc: RichTextLabel
var _use_btn: Button
var _notes_box: VBoxContainer
var _note_body: RichTextLabel
var _tab_items: Button
var _tab_journal: Button

var _selected := -1
var _mode := "items"


func _ready() -> void:
	UiTheme.fullscreen(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()
	Game.inventory_changed.connect(_on_data_changed)
	Game.notes_changed.connect(_on_data_changed)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	UiTheme.fullscreen(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = UiTheme.make_panel(UiTheme.BG, UiTheme.BORDER, 2)
	_panel.position = Vector2(120, 60)
	_panel.custom_minimum_size = Vector2(1040, 600)
	_panel.size = Vector2(1040, 600)
	add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	col.add_child(header)
	header.add_child(UiTheme.make_label("ИНВЕНТАРЬ", 26, UiTheme.TEXT))
	_tab_items = UiTheme.make_button("ПРЕДМЕТЫ", 18)
	_tab_items.pressed.connect(func() -> void: _set_mode("items"))
	header.add_child(_tab_items)
	_tab_journal = UiTheme.make_button("ЖУРНАЛ", 18)
	_tab_journal.pressed.connect(func() -> void: _set_mode("journal"))
	header.add_child(_tab_journal)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(300, 0)
	header.add_child(spacer)
	var close := UiTheme.make_button("[I] закрыть", 18)
	close.pressed.connect(close_panel)
	header.add_child(close)

	# --- предметы
	_items_view = HBoxContainer.new()
	_items_view.add_theme_constant_override("separation", 22)
	col.add_child(_items_view)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	_items_view.add_child(left)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	left.add_child(_grid)
	left.add_child(UiTheme.make_label("Стрелки/WASD — выбор · ПРОБЕЛ — использовать", 14, UiTheme.DIM))

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.custom_minimum_size = Vector2(520, 0)
	_items_view.add_child(right)

	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(520, 300)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	right.add_child(_preview)

	_name_label = UiTheme.make_label("Пусто", 22, UiTheme.GOLD)
	right.add_child(_name_label)

	_desc = UiTheme.make_rich("", 17, UiTheme.TEXT)
	_desc.custom_minimum_size = Vector2(520, 120)
	right.add_child(_desc)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	right.add_child(btns)
	_use_btn = UiTheme.make_button("ИСПОЛЬЗОВАТЬ", 18)
	_use_btn.pressed.connect(_use_selected)
	btns.add_child(_use_btn)

	# --- журнал
	_journal_view = HBoxContainer.new()
	_journal_view.add_theme_constant_override("separation", 22)
	_journal_view.visible = false
	col.add_child(_journal_view)

	_notes_box = VBoxContainer.new()
	_notes_box.add_theme_constant_override("separation", 6)
	_notes_box.custom_minimum_size = Vector2(360, 0)
	_journal_view.add_child(_notes_box)

	_note_body = UiTheme.make_rich("Здесь появятся записи, которые ты найдёшь.", 17, UiTheme.TEXT)
	_note_body.custom_minimum_size = Vector2(620, 460)
	_journal_view.add_child(_note_body)


func open(tab: String = "items") -> void:
	visible = true
	_set_mode(tab)
	refresh()


func close_panel() -> void:
	visible = false
	closed.emit()


func _set_mode(mode: String) -> void:
	_mode = mode
	_items_view.visible = mode == "items"
	_journal_view.visible = mode == "journal"
	_tab_items.modulate = Color(1, 1, 1) if mode == "items" else UiTheme.DIM
	_tab_journal.modulate = Color(1, 1, 1) if mode == "journal" else UiTheme.DIM
	refresh()


func _on_data_changed() -> void:
	if visible:
		refresh()


func refresh() -> void:
	_refresh_items()
	_refresh_journal()


func _refresh_items() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var inv := Game.inventory
	if _selected >= inv.size():
		_selected = inv.size() - 1
	if _selected < 0 and inv.size() > 0:
		_selected = 0
	var slots := maxi(12, inv.size())
	for i in slots:
		var b := Button.new()
		b.custom_minimum_size = Vector2(78, 78)
		b.expand_icon = true
		b.flat = true
		b.focus_mode = Control.FOCUS_ALL
		var sb := UiTheme.panel_box(
			Color(0.08, 0.08, 0.09, 0.9) if i != _selected else Color(0.16, 0.10, 0.11, 0.95),
			UiTheme.GOLD if i == _selected else UiTheme.BORDER, 2 if i == _selected else 1)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("focus", sb)
		b.add_theme_stylebox_override("pressed", sb)
		if i < inv.size():
			b.icon = Items.icon_of(inv[i])
			b.tooltip_text = Items.name_of(inv[i])
			b.pressed.connect(_select.bind(i))
		else:
			b.disabled = true
		_grid.add_child(b)

	if inv.is_empty():
		_preview.texture = null
		_name_label.text = "Пусто"
		_desc.text = "Карманы пусты. Всё, что ты найдёшь внизу, останется с тобой."
		_use_btn.disabled = true
		return
	var id := inv[_selected]
	_preview.texture = Items.icon_of(id)
	_name_label.text = Items.name_of(id)
	_desc.text = Items.desc_of(id)
	_use_btn.disabled = not Items.is_usable(id)


func _select(index: int) -> void:
	_selected = index
	_refresh_items()


func _use_selected() -> void:
	var inv := Game.inventory
	if _selected < 0 or _selected >= inv.size():
		return
	var id := inv[_selected]
	if not Items.is_usable(id):
		Game.toast("Это нельзя использовать здесь.")
		return
	var kind := str(Items.get_item(id).get("kind", "quest"))
	if kind == "air":
		var breath := Items.air_amount(id)
		Game.add_air(float(breath))
		Game.remove_item(id)
		Audio.play("pickup", -3.0)
		Game.toast("Воздух: +%d%%" % breath)
		refresh()
		return
	if kind == "lamp":
		var charge := Items.lamp_amount(id)
		Game.add_lamp(float(charge))
		Game.remove_item(id)
		Audio.play("pickup", -3.0)
		Game.toast("Заряд лампы: +%d%%" % charge)
		refresh()
		return
	var amount := Items.heal_amount(id)
	Game.heal(amount)
	Game.remove_item(id)
	Audio.play("pickup", -3.0)
	Game.toast("Здоровье восстановлено: +%d" % amount)
	refresh()


func _refresh_journal() -> void:
	for c in _notes_box.get_children():
		c.queue_free()
	if Game.notes.is_empty():
		_note_body.text = "Здесь появятся записи, которые ты найдёшь.\n\nПока — тишина и четыре этажа вниз."
		return
	for n in Game.notes:
		var b := UiTheme.make_button("• " + str(n.get("title", "")), 17)
		b.pressed.connect(func() -> void:
			_note_body.text = "[b]%s[/b]\n\n%s" % [str(n.get("title", "")), str(n.get("body", ""))])
		_notes_box.add_child(b)
	_note_body.text = "[b]%s[/b]\n\n%s" % [str(Game.notes[0].get("title", "")), str(Game.notes[0].get("body", ""))]


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.echo:
		return
	if _mode != "items":
		if event.is_action_pressed("inventory") or event.is_action_pressed("pause") or event.is_action_pressed("journal"):
			close_panel()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory") or event.is_action_pressed("pause"):
		close_panel()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		_move_selection(1)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		_move_selection(-1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		_move_selection(4)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		_move_selection(-4)
	elif event.is_action_pressed("attack"):
		_use_selected()
	else:
		return
	get_viewport().set_input_as_handled()


func _move_selection(delta: int) -> void:
	var n := Game.inventory.size()
	if n <= 0:
		return
	_selected = clampi(_selected + delta, 0, n - 1)
	_refresh_items()
