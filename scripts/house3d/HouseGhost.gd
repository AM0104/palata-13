class_name HouseGhost
extends Node3D
## Хозяйка дома. Плывёт сквозь стены, но теряет след. Видна только после первой печати.
## Догоняет — отнимает сердце и уходит. Убежать можно: игрок быстрее.

signal touched

const SPEED_IDLE := 0.75
const SPEED_HUNT := 2.55
const SENSE_DIST := 7.5
const CATCH_DIST := 1.15

var player: Node3D
var cells: Array = []
var state := "dormant"
var active := false

var _hunt_time := 0.0
var _cooldown := 0.0
var _waypoint := Vector3.ZERO
var _wait := 0.0
var _phase := 0.0
var _alpha := 0.0
var _mats: Array[StandardMaterial3D] = []
var _hair_mats: Array[StandardMaterial3D] = []
var _space: PhysicsDirectSpaceState3D
var _heart_tick := 0.0


func _ready() -> void:
	_build()
	visible = false


func _build() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.66, 0.8, 0.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.95
	mat.metallic = 0.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats.append(mat)

	# подол — расширяющийся книзу конус, фигура читается как женская
	var skirt := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.19
	cone.bottom_radius = 0.44
	cone.height = 1.05
	cone.radial_segments = 16
	skirt.mesh = cone
	skirt.material_override = mat
	skirt.position = Vector3(0, -0.33, 0)
	add_child(skirt)

	var torso := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.185
	capsule.height = 0.78
	capsule.radial_segments = 12
	torso.mesh = capsule
	torso.material_override = mat
	torso.position = Vector3(0, 0.4, 0)
	torso.rotation_degrees = Vector3(0, 0, 2.5)
	add_child(torso)

	# руки вдоль тела
	for sx in [-0.22, 0.22]:
		var arm := MeshInstance3D.new()
		var arm_mesh := CapsuleMesh.new()
		arm_mesh.radius = 0.055
		arm_mesh.height = 0.72
		arm_mesh.radial_segments = 8
		arm.mesh = arm_mesh
		arm.material_override = mat
		arm.position = Vector3(sx, 0.32, 0.02)
		arm.rotation_degrees = Vector3(8, 0, 6 if sx < 0 else -6)
		add_child(arm)

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.165
	sphere.height = 0.34
	sphere.radial_segments = 14
	head.mesh = sphere
	head.material_override = mat
	head.position = Vector3(0, 0.95, 0)
	add_child(head)

	# волосы — тёмная масса за головой
	var hair_mat := StandardMaterial3D.new()
	hair_mat.albedo_color = Color(0.06, 0.06, 0.09, 0.55)
	hair_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hair_mat.roughness = 1.0
	hair_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hair_mats.append(hair_mat)
	var hair := MeshInstance3D.new()
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.2
	hair_mesh.height = 0.55
	hair.mesh = hair_mesh
	hair.material_override = hair_mat
	hair.position = Vector3(0, 0.9, 0.07)
	add_child(hair)

	# глаза — два красных огонька
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.9, 0.1, 0.1)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.08, 0.06)
	eye_mat.emission_energy_multiplier = 4.0
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for sx in [-0.06, 0.06]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.026
		es.height = 0.052
		eye.mesh = es
		eye.material_override = eye_mat
		eye.position = Vector3(sx, 0.97, -0.15)
		add_child(eye)

	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.4, 0.55, 0.95)
	lamp.light_energy = 1.2
	lamp.omni_range = 3.6
	lamp.shadow_enabled = false
	lamp.position = Vector3(0, 1.0, 0)
	add_child(lamp)

	var catch_area := Area3D.new()
	catch_area.collision_layer = 0
	catch_area.collision_mask = 2
	catch_area.monitoring = true
	var cs := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = CATCH_DIST
	cs.shape = sphere_shape
	catch_area.add_child(cs)
	add_child(catch_area)


func awaken() -> void:
	if active:
		return
	active = true
	state = "idle"
	_cooldown = 3.0
	visible = true
	_alpha = 0.0
	_pick_waypoint()
	Audio.play("reveal", -4.0)


func is_hunting() -> bool:
	return state == "hunt"


## Принудительный поиск: срабатывает, когда снята последняя печать.
func start_hunt_now() -> void:
	if not active:
		awaken()
	state = "hunt"
	_hunt_time = 0.0
	_cooldown = 0.0
	Audio.play("reveal", -4.0)


func _process(delta: float) -> void:
	if not active or player == null:
		return
	_phase += delta
	_cooldown = maxf(0.0, _cooldown - delta)

	# прозрачность
	var want_alpha := 0.5
	if state == "hunt":
		want_alpha = 0.9
	_alpha = lerpf(_alpha, want_alpha, clampf(delta * 2.4, 0.0, 1.0))
	for m in _mats:
		m.albedo_color.a = _alpha * (0.82 + 0.18 * sin(_phase * 3.1))
	for m in _hair_mats:
		m.albedo_color.a = _alpha * 0.85

	var target_alpha := _alpha
	visible = target_alpha > 0.03

	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()

	if state == "idle":
		_wait -= delta
		if _wait <= 0.0:
			_pick_waypoint()
		var dir := _waypoint - global_position
		dir.y = 0.0
		if dir.length() < 0.6:
			_wait = randf_range(0.6, 2.0)
		else:
			global_position += dir.normalized() * SPEED_IDLE * delta
			_face(dir)
		if _cooldown <= 0.0 and dist < SENSE_DIST and _can_see():
			_start_hunt()
	elif state == "hunt":
		_hunt_time += delta
		var step := to_player.normalized() * SPEED_HUNT * delta
		global_position += step
		_face(to_player)
		global_position.y = _floor_here() + 1.0 + sin(_phase * 1.6) * 0.06
		_heart_tick += delta
		if _heart_tick > 0.95 and dist < 11.0:
			_heart_tick = 0.0
			Audio.play("heartbeat", -8.0)
		if dist < CATCH_DIST:
			touched.emit()
			_retreat()
		elif _hunt_time > 11.0 or dist > 20.0:
			state = "idle"
			_cooldown = 12.0
			_pick_waypoint()
			Audio.play("reveal", -16.0)


func _start_hunt() -> void:
	state = "hunt"
	_hunt_time = 0.0
	Audio.play("reveal", -8.0)


func _retreat() -> void:
	state = "idle"
	_cooldown = 9.0
	_hunt_time = 0.0
	_heart_tick = 0.0
	# исчезнуть и объявиться далеко: иначе она бьёт стоящего на месте игрока
	_alpha = 0.0
	_pick_waypoint(true)
	global_position = Vector3(_waypoint.x, 0.0, _waypoint.z)
	global_position.y = _floor_here() + 1.0


func _pick_waypoint(far_from_player: bool = false) -> void:
	if cells.is_empty():
		_waypoint = global_position
		_wait = 1.0
		return
	var best := _waypoint
	var best_score := -1.0
	for i in 6:
		var c: Vector3 = cells[randi() % cells.size()]
		var score := c.distance_to(player.global_position) if far_from_player else randf() * 10.0
		if score > best_score:
			best_score = score
			best = c
	_waypoint = Vector3(best.x, _floor_here(), best.z)
	_wait = randf_range(0.3, 1.2)


func _floor_here() -> float:
	if _space == null:
		_space = get_world_3d().direct_space_state
	var from := Vector3(global_position.x, global_position.y + 1.5, global_position.z)
	var query := PhysicsRayQueryParameters3D.create(from, from - Vector3(0, 4.5, 0), 1)
	var hit := _space.intersect_ray(query)
	if hit.is_empty():
		return 0.0
	return float(hit.get("position").y)


func _can_see() -> bool:
	if _space == null:
		_space = get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 1.0, 0)
	var to := player.global_position + Vector3(0, 0.9, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := _space.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider: Object = hit.get("collider")
	if collider == player:
		return true
	var p: Vector3 = hit.get("position")
	return p.distance_to(from) > from.distance_to(to) - 0.4


func _face(dir: Vector3) -> void:
	if dir.length() < 0.01:
		return
	var target_yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 0.08)
