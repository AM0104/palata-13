extends Node
## Проверка выживания: заряд лампы и воздуха реально тратятся, расходники работают.
var main: Node

func _ready() -> void:
	main = get_parent()
	await _wait(0.5)
	main._on_new_game()
	await _wait(0.2)
	Game.set_flag("intro:B5")
	main.ui.close_modals()
	await _wait(2.0)
	print("SURVIVAL lamp=%.1f air=%.1f paused=%s dead=%s phys=%s world=%s" % [Game.lamp_charge, Game.air, str(get_tree().paused), str(Game._is_dead), str(main.world.player.is_physics_processing()), str(main.world.player.world != null)])
	var ok_lamp := Game.lamp_charge < 100.0
	var ok_air := Game.air < 100.0
	Game.add_lamp(40.0)
	Game.add_air(40.0)
	print("SURVIVAL refill lamp=%.1f air=%.1f" % [Game.lamp_charge, Game.air])
	Game.lamp_charge = 100.0
	Game.air = 100.0
	var ok_items := Items.is_usable("battery") and Items.is_usable("respirator")
	Game.begin_shift()
	Game.shift_start_time = Game.play_time - 10.0
	Game.add_note("Тестовая запись", "Проверка ранга.")
	var rep := Game.finish_shift({"time": 100.0, "notes": 1, "title": "ТЕСТ"})
	print("RANK-TEST rank=%s time=%.1f notes=%d" % [str(rep.get("rank", "?")), float(rep.get("time", 0.0)), int(rep.get("notes", 0))])
	print("SURVIVAL-TEST lamp_drain=%s air_drain=%s items=%s" % [str(ok_lamp), str(ok_air), str(ok_items)])
	get_tree().quit()

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
