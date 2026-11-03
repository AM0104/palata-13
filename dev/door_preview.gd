extends Node
## Крупные скриншоты дверей «закрыто / открыто» по всем этажам: видно, совпадает ли
## полотно с проёмом и как створка отходит.
## Запуск: godot --path . -- --door-preview
##
## Ожидание — по кадрам, а не по секундам: окно без фокуса рендерится редко, и
## твины успевают не продвинуться.

const WAIT_FRAMES := 24
const OFFSETS := [Vector2(0, 96), Vector2(0, -96), Vector2(96, 0), Vector2(-96, 0)]

var main: Node


func _ready() -> void:
	main = get_parent()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp_preview"))
	await _frames(2)
	main._on_new_game()
	await _frames(4)
	for f in ["B5", "B4", "B3", "B2"]:
		Game.set_flag("intro:%s" % f)
	for idx in [0, 1, 2, 3]:
		await _floor(idx)
	get_tree().quit()


func _floor(idx: int) -> void:
	main.load_floor(idx)
	await _frames(WAIT_FRAMES)
	main.ui.close_modals()
	await _frames(4)
	var doors: Array = []
	for it in main.world.get_tree().get_nodes_in_group("interactables"):
		if it is Interactable and it.kind == "door":
			doors.append(it)
	var fid := str(main.world.level.get("id", "?"))
	print("--- %s: дверей %d" % [fid, doors.size()])
	for i in mini(3, doors.size()):
		await _one(fid, i, doors[i])


func _one(fid: String, i: int, door: Interactable) -> void:
	var cam: Camera2D = main.world.player.camera
	print("    %-22s %s" % [str(door.data.get("label", "?")), door._geom.describe()])
	if door.is_open():
		door.set_door_open(false)
		await _frames(WAIT_FRAMES)
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(3.0, 3.0)
	main.world.player.set_physics_process(false)
	var off: Vector2 = OFFSETS[i % OFFSETS.size()]
	main.world.player.global_position = door.global_position + off
	cam.position = -off
	cam.force_update_scroll()
	await _frames(4)
	await _shot("door_%s_%d_closed" % [fid, i])
	main.ui.close_modals()
	door.set_door_open(true)
	await _frames(WAIT_FRAMES)
	print("    створка: %s, открыта %s" % [_angles(door), str(door.is_open())])
	await _shot("door_%s_%d_open" % [fid, i])
	door.set_door_open(false)
	await _frames(4)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _angles(door: Interactable) -> Array:
	var out: Array = []
	for l in door._leaves:
		var sp := l as Sprite2D
		if door._leaf_standing:
			out.append("scale %.2f" % sp.scale.x)
		else:
			out.append("%.0f°" % rad_to_deg(sp.rotation))
	return out


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://.tmp_preview/%s.png" % name)
	var err := img.save_png(path)
	print("SHOT %s -> err=%d" % [name, err])
