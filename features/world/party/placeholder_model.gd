extends RefCounted

## Modelos provisorios armados con primitivas, para los Youns que todavía no
## tienen modelo 3D (YounData.scene_idle vacío). Cada Youn elige forma, color y
## tamaño (YounData.placeholder_*). Miran hacia +Z. PLACEHOLDER.

enum Shape { BOLITA, ALTO, CUERNOS, SERPIENTE, CUADRUPEDO, ESPIRITU }

static func build(data: YounData) -> Node3D:
	var root := Node3D.new()
	var color: Color = data.placeholder_color if data != null else Color(0.95, 0.8, 0.55)
	var shape: int = data.placeholder_shape if data != null else Shape.BOLITA
	var skin := _mat(color)
	var dark := _mat(color.darkened(0.35))
	match shape:
		Shape.ALTO:
			_add(root, _capsule(0.28, 0.9, skin), Vector3(0, 0.45, 0))
			_add(root, _sphere(0.24, skin), Vector3(0, 1.05, 0))
			_eyes(root, 1.1, 0.2)
		Shape.CUERNOS:
			_add(root, _sphere(0.42, skin), Vector3(0, 0.42, 0))
			for side in [-1.0, 1.0]:
				var horn := _add(root, _cone(0.08, 0.35, dark), Vector3(side * 0.22, 0.85, 0))
				horn.rotation_degrees.z = -side * 20.0
			_eyes(root, 0.52, 0.37)
		Shape.SERPIENTE:
			for i in 5:
				var r := 0.2 - i * 0.02
				_add(root, _sphere(r, skin if i % 2 == 0 else dark), Vector3(sin(i * 1.2) * 0.25, r, -i * 0.28))
			_add(root, _sphere(0.24, skin), Vector3(0, 0.42, 0.2))
			_eyes(root, 0.5, 0.42)
		Shape.CUADRUPEDO:
			_add(root, _box(Vector3(0.5, 0.35, 0.9), skin), Vector3(0, 0.5, 0))
			for x in [-0.18, 0.18]:
				for z in [-0.32, 0.32]:
					_add(root, _cylinder(0.07, 0.35, dark), Vector3(x, 0.17, z))
			_add(root, _sphere(0.25, skin), Vector3(0, 0.8, 0.5))
			var tail := _add(root, _cylinder(0.05, 0.5, dark), Vector3(0, 0.65, -0.6))
			tail.rotation_degrees.x = 50.0
			_eyes(root, 0.85, 0.72)
		Shape.ESPIRITU:
			var body := _add(root, _cone(0.35, 0.9, skin), Vector3(0, 0.75, 0))
			body.rotation_degrees.x = 180.0
			_add(root, _sphere(0.3, skin), Vector3(0, 1.3, 0))
			var glow := _mat(color.lightened(0.4))
			glow.emission_enabled = true
			glow.emission = color
			_add(root, _sphere(0.1, glow), Vector3(0, 1.75, 0))
			_eyes(root, 1.35, 0.26)
		_:
			_add(root, _sphere(0.35, skin, 0.6), Vector3(0, 0.3, 0))
			_eyes(root, 0.38, 0.3)
	var size: float = data.placeholder_size if data != null else 1.0
	root.scale = Vector3.ONE * size
	return root

static func _eyes(root: Node3D, height: float, forward: float) -> void:
	var eye := _mat(Color(0.08, 0.08, 0.1))
	for side in [-1.0, 1.0]:
		_add(root, _sphere(0.05, eye), Vector3(side * 0.11, height, forward))

static func _add(root: Node3D, mesh: Mesh, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	root.add_child(mi)
	return mi

static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.7
	return m

static func _sphere(radius: float, mat: Material, height := -1.0) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = height if height > 0.0 else radius * 2.0
	m.material = mat
	return m

static func _capsule(radius: float, height: float, mat: Material) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.material = mat
	return m

static func _cone(radius: float, height: float, mat: Material) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = height
	m.material = mat
	return m

static func _cylinder(radius: float, height: float, mat: Material) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.material = mat
	return m

static func _box(size: Vector3, mat: Material) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	m.material = mat
	return m
