extends Node
## Замер производительности 3D-режима и проверка поворота камеры мышью.
## Запуск: godot --path . --rendering-driver opengl3 res://scenes/House3D.tscn -- --bench-3d

var game: Node


func setup(g: Node) -> void:
	game = g
	call_deferred("_run")


func _run() -> void:
	await _wait(2.0)
	_test_mouse()
	await _wait(0.3)

	print("BENCH materials=%d" % _unique_materials())
	print("BENCH baseline      %s" % await _measure(4.0))

	var moon: DirectionalLight3D = game.get_node_or_null("Moon")
	if moon != null:
		moon.shadow_enabled = false
		print("BENCH no_moon_shadow %s" % await _measure(4.0))
		moon.shadow_enabled = true

	var torch: SpotLight3D = game.player.flashlight
	torch.shadow_enabled = false
	print("BENCH no_spot_shadow %s" % await _measure(4.0))
	torch.shadow_enabled = true

	moon.shadow_enabled = false
	torch.shadow_enabled = false
	print("BENCH no_shadows_at_all %s" % await _measure(4.0))
	moon.shadow_enabled = true
	torch.shadow_enabled = true

	var halo: OmniLight3D = game.player.get_node_or_null("Halo")
	if halo != null:
		halo.visible = false
		for c in game._candles:
			if c.get("light") != null:
				c["light"].visible = false
		print("BENCH no_point_lights  %s" % await _measure(4.0))
		halo.visible = true
		for c in game._candles:
			if c.get("light") != null:
				c["light"].visible = true

	var we: WorldEnvironment = game.get_node_or_null("WorldEnv")
	if we != null:
		we.environment.fog_enabled = false
		print("BENCH no_fog          %s" % await _measure(4.0))
		we.environment.fog_enabled = true

	print("BENCH draw_calls=%d objects=%d prims=%d" % [
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])
	print("BENCH mouse_mode=%d embedded=%s" % [
		int(Input.mouse_mode), str(Engine.is_embedded_in_editor())])
	print("BENCH DONE")
	await _wait(0.3)
	get_tree().quit()


func _measure(seconds: float) -> String:
	await _wait(0.4)
	var t0 := Time.get_ticks_msec()
	var f0 := Engine.get_frames_drawn()
	await _wait(seconds)
	var dt := float(Time.get_ticks_msec() - t0) / 1000.0
	var frames := Engine.get_frames_drawn() - f0
	return "fps=%.1f frames=%d" % [float(frames) / dt, frames]


func _unique_materials() -> int:
	var seen := {}
	for node in game._collect_meshes(game._model):
		var mi: MeshInstance3D = node
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat: Material = mi.mesh.surface_get_material(i)
			if mat == null and mi.material_override != null:
				mat = mi.material_override
			if mat != null:
				seen[mat.get_instance_id()] = true
	return seen.size()


## Проверяем, что событие мыши действительно вращает камеру.
func _test_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var before: float = game.player.rotation.y
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(120, 40)
	ev.screen_relative = Vector2(120, 40)
	game.player._unhandled_input(ev)
	var after: float = game.player.rotation.y
	var pitch: float = game.player.camera.rotation.x
	print("BENCH mouse_yaw=%.4f->%.4f pitch=%.4f mode=%d" % [
		before, after, pitch, int(Input.mouse_mode)])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
