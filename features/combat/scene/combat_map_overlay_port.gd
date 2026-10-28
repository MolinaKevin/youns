class_name CombatMapOverlayPort
extends RefCounted

## Primitivas compartidas para construir y mostrar overlays del tablero.
func make_material(_color: Color) -> StandardMaterial3D: return null
func make_disc(_color: Color) -> MeshInstance3D: return null
func show_disc(_mesh: MeshInstance3D, _center: Vector2, _radius: float) -> void: pass
func show_simple_disc(_mesh: MeshInstance3D, _center: Vector2, _radius: float) -> void: pass
func show_disc_with_los(_mesh: MeshInstance3D, _origin: Vector2, _radius: float, _elevation: int = 0) -> void: pass
func build_tile_disc(_mesh: MeshInstance3D, _center: Vector2, _radius: float, _inner_radius: float, _y: float, _exclusions: Array = []) -> void: pass
func apply_two_surface_mesh(_mesh: MeshInstance3D, _front_vertices: PackedVector3Array,
		_front_indices: PackedInt32Array, _back_vertices: PackedVector3Array,
		_back_indices: PackedInt32Array) -> void: pass
