class_name CombatMapPuddleVisualPresentation
extends CombatMapPuddleVisualPort
const CombatEffects := preload("res://features/combat/scene/combat_effect.gd")

## Implementación real: pide materiales/discos al overlay compartido del
## tablero (CombatMapOverlayPort) y cuelga los MeshInstance3D de `node`
## (hoy, el propio PuddleSystem) — misma geometría que antes vivía adentro
## de PuddleSystem, solo que ahora PuddleSystem no la conoce.

var overlay: CombatMapOverlayPort
var node: Node3D


func show_puddle(pos: Vector2, radius: float, effect: String, exclusions: Array = []) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var base := CombatEffects.puddle_color(effect)
	mi.set_meta("fill_mat", overlay.make_material(Color(base.r, base.g, base.b, 0.35)))
	mi.set_meta("bord_mat", overlay.make_material(Color(
		minf(base.r + 0.2, 1.0), minf(base.g + 0.2, 1.0), minf(base.b + 0.2, 1.0), 0.80)))
	node.add_child(mi)
	overlay.build_tile_disc(mi, pos, radius, 0.0, 0.013, exclusions)
	return mi


func show_lens(c1: Vector2, r1: float, c2: Vector2, r2: float, effect: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var base := CombatEffects.puddle_color(effect)
	mi.set_meta("fill_mat", overlay.make_material(Color(base.r, base.g, base.b, 1.0)))
	mi.set_meta("bord_mat", overlay.make_material(Color(
		minf(base.r + 0.15, 1.0), minf(base.g + 0.15, 1.0), minf(base.b + 0.15, 1.0), 1.0)))
	node.add_child(mi)
	_build_lens_disc(mi, c1, r1, c2, r2, 0.016)
	return mi


func remove_visual(mesh: MeshInstance3D) -> void:
	if is_instance_valid(mesh):
		mesh.queue_free()


func _build_lens_disc(mi: MeshInstance3D, c1: Vector2, r1: float, c2: Vector2, r2: float, y: float) -> void:
	const BORDER := 0.010
	var cell     := CombatGrid.CELL
	var half     := cell * 0.5
	var fill_v   := PackedVector3Array(); var fill_i := PackedInt32Array()
	var bord_v   := PackedVector3Array(); var bord_i := PackedInt32Array()
	var min_x := maxf(c1.x - r1, c2.x - r2)
	var max_x := minf(c1.x + r1, c2.x + r2)
	var min_y := maxf(c1.y - r1, c2.y - r2)
	var max_y := minf(c1.y + r1, c2.y + r2)
	for gx in range(int(floor(min_x / cell)), int(ceil(max_x / cell)) + 1):
		for gy in range(int(floor(min_y / cell)), int(ceil(max_y / cell)) + 1):
			var cx := (gx + 0.5) * cell
			var cy := (gy + 0.5) * cell
			if Vector2(cx, cy).distance_to(c1) > r1: continue
			if Vector2(cx, cy).distance_to(c2) > r2: continue
			var fi := fill_v.size()
			fill_v.append(Vector3(cx-half+BORDER, y,       cy-half+BORDER))
			fill_v.append(Vector3(cx+half-BORDER, y,       cy-half+BORDER))
			fill_v.append(Vector3(cx+half-BORDER, y,       cy+half-BORDER))
			fill_v.append(Vector3(cx-half+BORDER, y,       cy+half-BORDER))
			fill_i.append_array([fi, fi+1, fi+2, fi, fi+2, fi+3])
			for s: Array in [
				[cx-half, cy-half,        cx+half,        cy-half+BORDER],
				[cx-half, cy+half-BORDER, cx+half,        cy+half],
				[cx-half, cy-half+BORDER, cx-half+BORDER, cy+half-BORDER],
				[cx+half-BORDER, cy-half+BORDER, cx+half, cy+half-BORDER],
			]:
				var bi := bord_v.size()
				bord_v.append(Vector3(s[0], y+0.001, s[1])); bord_v.append(Vector3(s[2], y+0.001, s[1]))
				bord_v.append(Vector3(s[2], y+0.001, s[3])); bord_v.append(Vector3(s[0], y+0.001, s[3]))
				bord_i.append_array([bi, bi+1, bi+2, bi, bi+2, bi+3])
	overlay.apply_two_surface_mesh(mi, fill_v, fill_i, bord_v, bord_i)
