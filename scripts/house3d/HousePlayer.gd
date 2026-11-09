class_name HousePlayer
extends CharacterBody3D
## Игрок 3D-режима: ходьба от первого лица, фонарь с зарядом, луч взаимодействия.
## Мышь захватывается, пока не открыто меню или записка.

signal target_changed(target: Node)
signal interact_requested(target: Node)
signal battery_changed(value: float)
signal flashlight_changed(on: bool)
signal stepped(loud: bool)

const WALK_SPEED := 3.4
const RUN_SPEED := 5.6
const CROUCH_SPEED := 1.4
const ACCEL := 12.0
const MOUSE_SENS := 0.0022
const MAX_BATTERY := 100.0
const DRAIN_PER_SEC := 0.8
const EYE_HEIGHT := 0.72
const CROUCH_DROP := 0.42
const INTERACT_DIST := 3.2

var camera: Camera3D
var flashlight: SpotLight3D
var light_on := true
var battery := 86.0
var can_move := true

var _pitch := 0.0
var _bob := 0.0
var _bob_phase := 0.0
var _step_accum := 0.0
var _target: Node = null
var _invuln := 0.0
var _battery_tick := 0.0
var _space: PhysicsDirectSpaceState3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	up_direction = Vector3.UP
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(55.0)

	var capsule := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.height = 1.75
	shape.radius = 0.33
	capsule.shape = shape
	add_child(capsule)

	camera = Camera3D.new()
	camera.position = Vector3(0.0, EYE_HEIGHT, 0.0)
	camera.fov = 74.0
	camera.near = 0.05
	camera.far = 140.0
	camera.current = true
	add_child(camera)

	flashlight = SpotLight3D.new()
	flashlight.position = Vector3(0.12, -0.06, 0.0)
	flashlight.spot_range = 22.0
	flashlight.spot_angle = 33.0
	flashlight.spot_angle_attenuation = 1.4
	flashlight.spot_attenuation = 1.1
	flashlight.light_energy = 7.0
	flashlight.light_color = Color(1.0, 0.94, 0.78)
	flashlight.shadow_enabled = true
	flashlight.shadow_bias = 0.03
	camera.add_child(flashlight)

	# (ореол вокруг игрока убран: он стоил кадров, а ambient и фонарь дают достаточно света)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	battery_changed.emit(battery)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Работает и без захвата курсора (например, во встроенном окне редактора):
		# относительное смещение приходит в любом случае, курсор просто виден.
		if not can_move:
			return
		var motion: InputEventMouseMotion = event
		var sens := MOUSE_SENS * Settings.mouse_sensitivity
		rotation.y -= motion.relative.x * sens
		_pitch = clampf(_pitch - motion.relative.y * sens, -1.3, 1.3)
		if camera != null:
			camera.rotation.x = _pitch
	elif event.is_action_pressed("flashlight"):
		toggle_flashlight()
	elif event.is_action_pressed("interact") and _target != null and is_instance_valid(_target) and can_move:
		interact_requested.emit(_target)
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_invuln = maxf(0.0, _invuln - delta)

	if not can_move:
		velocity = Vector3.ZERO
		return

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := (global_transform.basis * Vector3(input.x, 0.0, input.y))
	dir.y = 0.0
	if dir.length() > 1.0:
		dir = dir.normalized()

	var crouch := Input.is_action_pressed("crouch")
	var speed := WALK_SPEED
	if crouch:
		speed = CROUCH_SPEED
	elif Input.is_action_pressed("sprint"):
		speed = RUN_SPEED

	var want := dir * speed
	var blend := clampf(ACCEL * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, want.x, blend)
	velocity.z = lerpf(velocity.z, want.z, blend)

	if is_on_floor():
		velocity.y = -0.2
	else:
		velocity.y -= 22.0 * delta

	move_and_slide()

	var moving := Vector2(velocity.x, velocity.z).length() > 0.6
	var eye := EYE_HEIGHT - (CROUCH_DROP if crouch else 0.0)
	if moving:
		_bob_phase += delta * (9.0 if speed > WALK_SPEED + 0.1 else 6.4)
		_bob = lerpf(_bob, 1.0, clampf(delta * 8.0, 0.0, 1.0))
		_step_accum += Vector2(velocity.x, velocity.z).length() * delta
		if _step_accum > (2.4 if speed > WALK_SPEED + 0.1 else 2.0):
			_step_accum = 0.0
			stepped.emit(speed > WALK_SPEED + 0.1)
	else:
		_bob = lerpf(_bob, 0.0, clampf(delta * 8.0, 0.0, 1.0))
	if camera != null:
		camera.position.y = eye + sin(_bob_phase) * 0.035 * _bob

	_drain_battery(delta)
	_scan_target()


func _drain_battery(delta: float) -> void:
	if not light_on:
		return
	var before := battery
	battery = maxf(0.0, battery - DRAIN_PER_SEC * delta)
	if battery <= 0.0:
		light_on = false
		if flashlight != null:
			flashlight.visible = false
		flashlight_changed.emit(false)
		Audio.play("deny", -10.0)
	_battery_tick += delta
	if _battery_tick > 0.25 and not is_equal_approx(before, battery):
		_battery_tick = 0.0
		battery_changed.emit(battery)


func _scan_target() -> void:
	if _space == null:
		_space = get_world_3d().direct_space_state
	var origin := camera.global_position
	var forward := -camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * INTERACT_DIST, 1 | 4)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := _space.intersect_ray(query)
	var found: Node = null
	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		if collider is HouseInteract:
			found = collider
	if _target != null and not is_instance_valid(_target):
		_target = null
		target_changed.emit(null)
	if found != _target:
		_target = found
		target_changed.emit(found)

func toggle_flashlight() -> void:
	if battery <= 0.0:
		Audio.play("deny", -10.0)
		return
	light_on = not light_on
	if flashlight != null:
		flashlight.visible = light_on
	Audio.play("ui", -18.0)
	flashlight_changed.emit(light_on)


func add_battery(amount: float) -> void:
	battery = clampf(battery + amount, 0.0, MAX_BATTERY)
	battery_changed.emit(battery)


func take_hit(from: Vector3) -> bool:
	if _invuln > 0.0:
		return false
	_invuln = 1.3
	var away := global_position - from
	away.y = 0.0
	if away.length() > 0.01:
		away = away.normalized()
	velocity.x += away.x * 5.0
	velocity.z += away.z * 5.0
	return true


func teleport_to(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO


func set_can_move(value: bool) -> void:
	can_move = value
	if not value:
		velocity = Vector3.ZERO


func current_target() -> Node:
	return _target
