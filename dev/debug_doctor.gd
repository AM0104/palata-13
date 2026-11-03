extends Node
## Отладка доктора: позиция, спрайт, видимость.
## Запуск: godot --path . --resolution 1280x720 -- --debug-doctor

var main: Node


func _ready() -> void:
	main = get_parent()
	await get_tree().create_timer(0.8).timeout
	Game.set_difficulty(1)
	main._on_new_game()
	await get_tree().create_timer(0.8).timeout
	main.ui.close_modals()
	var w: World = main.world
	w.player.teleport(Vector2(20 * 32, 13.5 * 32))
	await get_tree().create_timer(0.3).timeout
	w.spawn_doctor()
	await get_tree().create_timer(0.3).timeout
	var d: Enemy = w.doctor
	print("DOCTOR? ", d)
	if d != null:
		print("  pos=", d.global_position, " tex=", d.sprite.texture, " visible=", d.sprite.visible, " modulate=", d.sprite.modulate)
		print("  z=", d.z_index, " ysort=", d.get_parent())
		d.global_position = w.player.global_position + Vector2(190, -30)
		await get_tree().create_timer(0.4).timeout
		print("  moved pos=", d.global_position, " dist=", d.global_position.distance_to(w.player.global_position))
		print("  tex size=", d.sprite.texture.get_size() if d.sprite.texture != null else "null")
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://captures/palata/debug_doctor.png"))
	get_tree().quit()
