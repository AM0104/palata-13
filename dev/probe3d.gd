extends Node3D
## Диагностика 3D-карты: печатает дерево и габариты, снимает облётные кадры.
## Запуск: godot --path . res://dev/probe3d.tscn

const OUT_DIR := "res://captures/map3d"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var packed: PackedScene = load("res://assets/maps/haunted_house.glb")
	var model: Node3D = packed.instantiate()
	add_child(model)

	var aabb := _aabb(model)
	print("MAP AABB position=%s size=%s" % [str(aabb.position), str(aabb.size)])
	print("MAP children=%d total_nodes=%d" % [model.get_child_count(), _count(model)])
	_dump(model, 0)

	# окружение и свет
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.09, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.6)
	env.ambient_light_energy = 1.2
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 40, 0)
	sun.light_energy = 1.4
	add_child(sun)

	var cam := Camera3D.new()
	cam.far = 4000.0
	add_child(cam)
	cam.current = true

	var c := aabb.get_center()
	var r := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	# облёт
	var shots := [
		["front", Vector3(0, 0.35, 2.1)],
		["back", Vector3(0, 0.35, -2.1)],
		["left", Vector3(-2.1, 0.35, 0)],
		["right", Vector3(2.1, 0.35, 0)],
		["top", Vector3(0, 2.2, 0.01)],
		["high", Vector3(1.2, 1.4, 1.6)],
	]
	for s in shots:
		var v: Vector3 = s[1]
		cam.position = c + v * r
		cam.look_at(c, Vector3.UP if absf(v.normalized().y) < 0.99 else Vector3.FORWARD)
		await _settle()
		await _shot("map_%s" % s[0])

	# вид изнутри: пробуем несколько точек внутри габарита
	var probes := [
		Vector3(c.x, aabb.position.y + aabb.size.y * 0.25, c.z),
		Vector3(c.x, aabb.position.y + aabb.size.y * 0.55, c.z),
		Vector3(c.x, aabb.position.y + aabb.size.y * 0.85, c.z),
	]
	var i := 0
	for p in probes:
		cam.position = p
		cam.rotation_degrees = Vector3(-8, 35, 0)
		await _settle()
		await _shot("inside_%d" % i)
		i += 1

	print("PROBE DONE")
	get_tree().quit()


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("%s/%s.png" % [OUT_DIR, name])
	img.save_png(path)
	print("SHOT %s %dx%d" % [name, img.get_width(), img.get_height()])


func _aabb(root: Node) -> AABB:
	var out := AABB()
	var first := true
	for mi in _meshes(root):
		var b: AABB = mi.get_aabb()
		var xf: Transform3D = mi.global_transform
		var wb := xf * b
		if first:
			out = wb
			first = false
		else:
			out = out.merge(wb)
	return out


func _meshes(root: Node) -> Array:
	var res: Array = []
	if root is MeshInstance3D:
		res.append(root)
	for c in root.get_children():
		res.append_array(_meshes(c))
	return res


func _count(root: Node) -> int:
	var n := 1
	for c in root.get_children():
		n += _count(c)
	return n


func _dump(root: Node, depth: int) -> void:
	if depth > 2:
		return
	var extra := ""
	if root is MeshInstance3D:
		extra = " mesh=%s" % root.mesh.resource_name
	print("%s%s [%s]%s" % ["  ".repeat(depth), root.name, root.get_class(), extra])
	for c in root.get_children():
		_dump(c, depth + 1)
