extends Node
var main: Node
func _ready() -> void:
	main = get_parent()
	await _wait(0.8)
	main._on_new_game()
	await _wait(1.2)
	main.ui.close_modals()
	await _wait(0.8)
	print("SPAWN alpha=%.2f" % main.ui.hud.map_panel.modulate.a)
	main.world.player.teleport(Vector2(448, 560))
	await _wait(0.8)
	var bg: StyleBoxFlat = main.ui.hud.prompt_panel.get_theme_stylebox("panel")
	print("PROMPT vis=%s covered=%s prompt='%s' bg_a=%.2f player_screen=%s" % [
		str(main.ui.hud.prompt_panel.visible), str(main.ui.hud._prompt_ghosted),
		main.ui.hud.prompt_label.text, bg.bg_color.a,
		str(main.world.player.camera.get_canvas_transform() * main.world.player.global_position)])
	await _shot("prompt")
	get_tree().quit()
func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout
func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://captures/probe5_%s.png" % n))
	print("CAPTURE %s" % n)
