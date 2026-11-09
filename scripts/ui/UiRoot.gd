class_name UiRoot
extends CanvasLayer
## Владелец всего интерфейса: HUD, диалоги, панели, инвентарь, карта, меню, финалы.

signal new_game_requested
signal continue_requested
signal house_requested
signal quit_requested
signal resume_requested
signal save_requested
signal to_menu_requested
signal retry_requested
signal restart_requested
signal difficulty_chosen(index: int)

var hud: Hud
var dialog: DialogUi
var panel: PanelUi
var inventory: InventoryUi
var map_ui: MapUi
var menu: MenuUi
var end_ui: EndUi
var difficulty_ui: DifficultyUi
var transition: TransitionUi

var main: Node = null
var world: World = null


func setup(main_ref: Node) -> void:
	main = main_ref
	layer = 10

	hud = Hud.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)

	map_ui = MapUi.new()
	add_child(map_ui)

	inventory = InventoryUi.new()
	inventory.closed.connect(_update_pause)
	add_child(inventory)

	panel = PanelUi.new()
	panel.closed.connect(_update_pause)
	add_child(panel)

	dialog = DialogUi.new()
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(dialog)

	transition = TransitionUi.new()
	add_child(transition)

	end_ui = EndUi.new()
	end_ui.retry_requested.connect(func() -> void: retry_requested.emit())
	end_ui.restart_requested.connect(func() -> void: restart_requested.emit())
	end_ui.to_menu_requested.connect(func() -> void: to_menu_requested.emit())
	add_child(end_ui)

	menu = MenuUi.new()
	menu.new_game_requested.connect(func() -> void: new_game_requested.emit())
	menu.continue_requested.connect(func() -> void: continue_requested.emit())
	menu.house_requested.connect(func() -> void: house_requested.emit())
	menu.quit_requested.connect(func() -> void: quit_requested.emit())
	menu.resume_requested.connect(func() -> void: resume_requested.emit())
	menu.save_requested.connect(func() -> void: save_requested.emit())
	menu.to_menu_requested.connect(func() -> void: to_menu_requested.emit())
	add_child(menu)

	# окно сложности добавляется последним, чтобы рисоваться поверх меню и финалов
	difficulty_ui = DifficultyUi.new()
	difficulty_ui.chosen.connect(func(i: int) -> void: difficulty_chosen.emit(i))
	difficulty_ui.cancelled.connect(_update_pause)
	add_child(difficulty_ui)


func bind_world(w: World) -> void:
	world = w
	hud.bind_world(w)
	map_ui.apply(w)


func set_hud_visible(v: bool) -> void:
	hud.visible = v


# --- диалоги и панели ------------------------------------------------------

func show_dialog(id: String) -> void:
	if id == "":
		return
	dialog.start(id, world)
	_update_pause()


func show_note(title: String, body: String) -> void:
	panel.show_text(title, body)
	_update_pause()


func show_code(it: Interactable) -> void:
	panel.show_code(it)
	_update_pause()


# --- экраны ----------------------------------------------------------------

func show_main_menu() -> void:
	close_modals()
	menu.show_main()
	hud.visible = false
	_update_pause()


## Окно выбора сложности перед стартом новой партии.
func show_difficulty() -> void:
	close_modals()
	difficulty_ui.open()
	_update_pause()


func show_floor_transition(report: Dictionary, target: int) -> void:
	if transition != null:
		transition.show_report(report, target)


func show_pause() -> void:
	menu.show_pause()
	_update_pause()


func show_death() -> void:
	end_ui.show_death()
	_update_pause()


func show_ending(id: String) -> void:
	if Game.ending == "":
		Game.ending = id
	end_ui.show_ending(id)
	_update_pause()


func toggle_inventory(tab: String = "items") -> void:
	if inventory.visible:
		inventory.close_panel()
	else:
		if any_modal():
			return
		inventory.open(tab)
	_update_pause()


func toggle_map() -> void:
	if map_ui.visible:
		map_ui.visible = false
	else:
		if any_modal():
			return
		map_ui.visible = true
	_update_pause()


func close_modals() -> void:
	dialog.visible = false
	transition.visible = false
	panel.visible = false
	inventory.visible = false
	map_ui.visible = false
	menu.visible = false
	end_ui.visible = false
	difficulty_ui.visible = false
	_update_pause()


func hide_all() -> void:
	close_modals()


func any_modal() -> bool:
	return dialog.visible or panel.visible or inventory.visible or map_ui.visible \
		or menu.visible or end_ui.visible or difficulty_ui.visible


func is_fullscreen_modal() -> bool:
	return inventory.visible or map_ui.visible or menu.visible or end_ui.visible \
		or panel.visible or difficulty_ui.visible


func _update_pause() -> void:
	if get_tree() == null:
		return
	get_tree().paused = any_modal()
