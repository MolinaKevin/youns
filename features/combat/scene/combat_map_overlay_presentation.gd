class_name CombatMapOverlayPresentation
extends CombatMapOverlayPort

var overlay: CombatMapOverlay
var renderer: CombatMapRenderer
var range_overlay: CombatRangeOverlay

func make_material(color: Color) -> StandardMaterial3D:
	return overlay.make_material(color)

func make_disc(color: Color) -> MeshInstance3D:
	return overlay.make_disc(color)

func show_disc(mesh: MeshInstance3D, center: Vector2, radius: float) -> void:
	renderer.show_disc(mesh, center, radius)

func show_simple_disc(mesh: MeshInstance3D, center: Vector2, radius: float) -> void:
	renderer.show_simple_disc(mesh, center, radius)

func show_disc_with_los(mesh: MeshInstance3D, origin: Vector2, radius: float, elevation: int = 0) -> void:
	range_overlay.show_disc_with_los(mesh, origin, radius, elevation, false, true)

func build_tile_disc(mesh: MeshInstance3D, center: Vector2, radius: float, inner_radius: float, y: float, exclusions: Array = []) -> void:
	renderer.build_tile_disc(mesh, center, radius, inner_radius, y, exclusions)

func apply_two_surface_mesh(mesh: MeshInstance3D, front_vertices: PackedVector3Array,
		front_indices: PackedInt32Array, back_vertices: PackedVector3Array,
		back_indices: PackedInt32Array) -> void:
	renderer.apply_two_surface_mesh(mesh, front_vertices, front_indices, back_vertices, back_indices)
