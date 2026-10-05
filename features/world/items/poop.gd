extends Node3D

## Caca en el suelo tras un accidente de baño. PLACEHOLDER de testeo: tres
## rollos marrones apilados y una puntita, armados con primitivas.

const COLOR := Color(0.36, 0.22, 0.1)
## Rollos de abajo hacia arriba: [radio, alto].
const COILS := [[0.18, 0.1], [0.14, 0.09], [0.1, 0.08]]

func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR
	mat.roughness = 0.6
	var y := 0.0
	for coil in COILS:
		var mesh := SphereMesh.new()
		mesh.radius = coil[0]
		mesh.height = coil[1] * 2.0
		mesh.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position.y = y + coil[1] * 0.6
		add_child(mi)
		y += coil[1]
	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.06
	tip.height = 0.1
	tip.material = mat
	var tip_mi := MeshInstance3D.new()
	tip_mi.mesh = tip
	tip_mi.position.y = y + 0.08
	tip_mi.rotation_degrees.z = 12.0
	add_child(tip_mi)
