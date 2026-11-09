class_name HouseInteract
extends Area3D
## Предмет в доме: записка, печать, батарея или выход. Луч игрока находит Area3D,
## игра решает, что сделать при нажатии.

var kind := "note"
var id := ""
var title := ""
var body := ""
var prompt := "Осмотреть"
var done := false
var sealed := false

var _base_y := 0.0
var _phase := 0.0
var _spin: Node3D = null


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("house_interactable")

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.42
	shape.shape = sphere
	add_child(shape)

	_base_y = position.y
	_phase = randf() * TAU
	_build_visual()


func _process(delta: float) -> void:
	if kind != "seal" and kind != "battery":
		return
	_phase += delta
	if _spin != null:
		_spin.rotate_y(delta * 1.4)
		_spin.position.y = sin(_phase * 1.8) * 0.08


func _build_visual() -> void:
	match kind:
		"seal":
			_spin = Node3D.new()
			add_child(_spin)
			var mi := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = 0.17
			mesh.height = 0.36
			mesh.radial_segments = 4
			mesh.rings = 2
			mi.mesh = mesh
			mi.material_override = _glow(Color(1.0, 0.72, 0.28), 2.6)
			_spin.add_child(mi)
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.28
			torus.outer_radius = 0.32
			ring.mesh = torus
			ring.rotation_degrees = Vector3(90, 0, 0)
			ring.material_override = _glow(Color(0.9, 0.55, 0.2), 1.6)
			_spin.add_child(ring)
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.7, 0.32)
			lamp.light_energy = 1.5
			lamp.omni_range = 4.2
			lamp.shadow_enabled = false
			_spin.add_child(lamp)
		"battery":
			_spin = Node3D.new()
			add_child(_spin)
			var mi := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.055
			mesh.bottom_radius = 0.055
			mesh.height = 0.24
			mi.mesh = mesh
			mi.material_override = _glow(Color(0.35, 0.95, 0.55), 1.8)
			_spin.add_child(mi)
		"note":
			var mi := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(0.3, 0.4)
			mi.mesh = quad
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = _paper_texture()
			mat.emission_enabled = true
			mat.emission = Color(0.5, 0.46, 0.34)
			mat.emission_energy_multiplier = 0.25
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mi.material_override = mat
			mi.rotation_degrees = Vector3(-12, 0, 0)
			add_child(mi)
			_spin = mi
		"exit":
			var mi := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.18, 0.26, 0.06)
			mi.mesh = box
			mi.material_override = _glow(Color(0.85, 0.75, 0.45), 1.1)
			mi.position = Vector3(0, 0, 0)
			add_child(mi)
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.85, 0.5)
			lamp.light_energy = 0.8
			lamp.omni_range = 2.4
			lamp.shadow_enabled = false
			add_child(lamp)


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.roughness = 0.4
	return mat


func _paper_texture() -> Texture2D:
	var img := Image.create(32, 44, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.83, 0.79, 0.66))
	for y in range(5, 40, 4):
		for x in range(4, 28):
			img.set_pixel(x, y, Color(0.3, 0.26, 0.2))
	return ImageTexture.create_from_image(img)


## Убрать предмет из мира, оставив узел живым до конца кадра: игрок ещё держит
## ссылку на него как на текущую цель.
func consume() -> void:
	done = true
	monitorable = false
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = true
		elif c is MeshInstance3D and c != _spin:
			(c as MeshInstance3D).visible = false
	if _spin != null:
		_spin.visible = false
	visible = false
