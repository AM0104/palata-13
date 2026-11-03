class_name Player
extends CharacterBody2D
## Миша: ходьба, поиск ближайшего объекта взаимодействия, луч фонаря, урон и неуязвимость.

signal prompt_changed(text: String)
signal damaged(amount: int)
signal beam_fired

const SPEED := 112.0
const SPRINT_SPEED := 172.0
const SPRITE_SCALE := 0.34
const BEAM_RANGE := 128.0
const BEAM_ANGLE := 0.72       ## половина угла конуса, радианы
const BEAM_COST := 1.6
const BEAM_COOLDOWN := 0.42
const BEAM_DAMAGE := 1

var sprite: Sprite2D
var shadow: Sprite2D
var lamp: PointLight2D
var probe: Area2D
var camera: Camera2D

var facing := Vector2.DOWN
var dir_name := "down"
var input_enabled := true

var _bob := 0.0
var _invuln := 0.0
var _step_timer := 0.0
var _knock := Vector2.ZERO
var _target: Node = null
var _air_timer := 0.0
var _heart_timer := 0.0
var _beam_cd := 0.0
var world: Node = null
var sprinting := false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	y_sort_enabled = false

	shadow = Sprite2D.new()
	shadow.texture = Tex.shadow_texture(30, 13)
	shadow.position = Vector2(0, -1)
	shadow.modulate = Color(1, 1, 1, 0.75)
	add_child(shadow)

	sprite = Sprite2D.new()
	sprite.texture = Art.character_sprite("misha", dir_name)
	sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	sprite.position = Vector2(0, -22)
	add_child(sprite)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	shape.position = Vector2(0, -7)
	add_child(shape)

	probe = Area2D.new()
	probe.collision_layer = 0
	probe.collision_mask = 4
	var pshape := CollisionShape2D.new()
	var pcircle := CircleShape2D.new()
	pcircle.radius = 44.0
	pshape.shape = pcircle
	pshape.position = Vector2(0, -8)
	probe.add_child(pshape)
	add_child(probe)

	lamp = PointLight2D.new()
	lamp.texture = Tex.light_texture(256)
	lamp.texture_scale = 1.05
	lamp.energy = 0.55
	lamp.color = Color(1.0, 0.94, 0.85)
	lamp.position = Vector2(0, -14)
	add_child(lamp)

	camera = Camera2D.new()
	camera.zoom = Vector2(1.2, 1.2)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	add_child(camera)


func _physics_process(delta: float) -> void:
	if _invuln > 0.0:
		_invuln -= delta
		sprite.modulate = Color(1, 0.6, 0.6, 0.6 + 0.4 * sin(_invuln * 40.0))
	else:
		sprite.modulate = Color(1, 1, 1, 1)
	if _beam_cd > 0.0:
		_beam_cd -= delta

	var dir := Vector2.ZERO
	if input_enabled and not Game.is_dead():
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var speed := SPEED
	sprinting = Input.is_action_pressed("sprint") and dir != Vector2.ZERO
	if sprinting:
		speed = SPRINT_SPEED

	# Воздух: обычный расход небольшой, в газовом кармане — очень быстрый.
	var in_gas: bool = world != null and world.has_method("gas_at") and world.gas_at(global_position)
	if in_gas:
		speed *= 0.72
	var air_drain := 0.24 + (1.55 if in_gas else 0.0)
	if not Game.is_dead():
		Game.drain_air(air_drain * delta * float(Game.difficulty_balance()["air_drain_mult"]))
		_air_timer -= delta
		_heart_timer -= delta
		if Game.air <= 0.0 and _air_timer <= 0.0:
			_air_timer = 2.7
			hurt(1, global_position)
			Game.toast("Воздух кончился. Лёгкие сводит.")
		elif Game.air_ratio() < 0.22 and _heart_timer <= 0.0:
			_heart_timer = 2.2
			Audio.play("heartbeat", -9.0)

	# Лампа — главный расходник: в темноте она садится, аккумуляторы редки.
	var drain := 0.30
	if dir != Vector2.ZERO:
		drain = 0.55 if speed == SPEED else 0.85
	if not Game.is_dead():
		Game.drain_lamp(drain * delta * float(Game.difficulty_balance()["lamp_drain_mult"]))
	var ratio := Game.lamp_ratio()
	lamp.energy = 0.08 + ratio * 0.52
	if ratio < 0.22:
		lamp.energy += sin(float(Time.get_ticks_msec()) * 0.03) * 0.035
	lamp.color = Color(1.0, 0.94 - (1.0 - ratio) * 0.18, 0.85 - (1.0 - ratio) * 0.25)

	velocity = dir.normalized() * speed + _knock
	_knock = _knock.lerp(Vector2.ZERO, clampf(delta * 8.0, 0.0, 1.0))
	move_and_slide()

	if dir != Vector2.ZERO:
		facing = dir.normalized()
		_update_dir_name(dir)
		_bob += delta * (14.0 if speed == SPRINT_SPEED else 10.0)
		sprite.position.y = -22 + sin(_bob) * 1.6
		sprite.rotation = sin(_bob * 0.5) * 0.018
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.34 if speed == SPRINT_SPEED else 0.44
			Audio.play("step" if Game.floor_index != 1 else "step_soft", -6.0)
	else:
		_bob = 0.0
		sprite.position.y = lerpf(sprite.position.y, -22.0, clampf(delta * 10.0, 0.0, 1.0))
		sprite.rotation = lerpf(sprite.rotation, 0.0, clampf(delta * 10.0, 0.0, 1.0))

	_update_target()

	if input_enabled and not Game.is_dead() and _beam_cd <= 0.0 \
			and Input.is_action_just_pressed("attack"):
		fire_beam()


## Луч фонаря: короткий конус, который развеивает призраков и отталкивает их.
## Доктору он не вредит — только на миг очерчивает его силуэт.
func fire_beam() -> void:
	_beam_cd = BEAM_COOLDOWN
	Game.drain_lamp(BEAM_COST)
	Audio.play("swing", -5.0)
	if world != null and world.has_method("shake_small"):
		world.shake_small()
	_spawn_beam_visual()
	var hit := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Enemy) or not is_instance_valid(e) or e.dead:
			continue
		var to: Vector2 = e.global_position - global_position
		if to.length() > BEAM_RANGE:
			continue
		if facing.normalized().dot(to.normalized()) < cos(BEAM_ANGLE):
			continue
		hit = true
		e.take_damage(BEAM_DAMAGE, global_position)
		e.stun(0.9)
	if hit:
		Audio.play("hit", -5.0)
	beam_fired.emit()


func _spawn_beam_visual() -> void:
	if world == null or not is_instance_valid(world):
		return
	var poly := Polygon2D.new()
	var pts := PackedVector2Array([Vector2.ZERO])
	var n := 9
	for i in n + 1:
		var a := -BEAM_ANGLE + (2.0 * BEAM_ANGLE) * float(i) / float(n)
		pts.append(Vector2.RIGHT.rotated(a) * BEAM_RANGE)
	poly.polygon = pts
	poly.rotation = facing.angle()
	poly.position = global_position + Vector2(0, -12)
	poly.color = Color(1.0, 0.92, 0.62, 0.22)
	poly.z_index = 6
	world.add_child(poly)
	var t := poly.create_tween()
	t.tween_property(poly, "modulate:a", 0.0, 0.2)
	t.tween_callback(poly.queue_free)


func _update_dir_name(dir: Vector2) -> void:
	var new_dir := dir_name
	if absf(dir.x) > absf(dir.y):
		new_dir = "side"
		sprite.flip_h = dir.x < 0.0
	elif dir.y < 0.0:
		new_dir = "up"
		sprite.flip_h = false
	else:
		new_dir = "down"
		sprite.flip_h = false
	if new_dir != dir_name:
		dir_name = new_dir
		sprite.texture = Art.character_sprite("misha", dir_name)


func _update_target() -> void:
	var best: Node = null
	var best_d := 1.0e9
	for area in probe.get_overlapping_areas():
		if area is Interactable and area.available:
			var d := global_position.distance_to(area.global_position)
			if d < best_d:
				best_d = d
				best = area
	if best != _target:
		_target = best
		prompt_changed.emit("" if best == null else best.prompt_text())


func current_target() -> Node:
	return _target


func try_interact() -> void:
	if _target != null and is_instance_valid(_target):
		_target.interact(self)
		_update_target()


func hurt(amount: int, from: Vector2 = Vector2.ZERO) -> void:
	if _invuln > 0.0 or Game.is_dead():
		return
	_invuln = 1.15 * float(Game.difficulty_balance()["invuln_mult"])
	if from != Vector2.ZERO:
		_knock = (global_position - from).normalized() * 210.0
	Game.damage(amount)
	Audio.play("hurt", -4.0)
	damaged.emit(amount)


func teleport(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_knock = Vector2.ZERO
