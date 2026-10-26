class_name PlacementPreview
extends RefCounted

## Charcos y trampas (ver puddle_system.gd/trap_system.gd) comparten este
## esqueleto de "tirar algo a una celda": un disco de rango al tirar + un
## preview de la celda apuntada, snapeado a la grilla. Lo único que cambia
## entre sistemas es el color (y, en charcos, que depende del efecto). Sin
## estado propio a propósito: cada sistema sigue siendo dueño de su _disc/
## _preview/último punto, así no hay ningún nodo ni orden de _ready() de por
## medio.

## El disco se cuelga de `owner` (el sistema que llama, no de `map`): colgarlo
## de `map` con add_child() falla en silencio si esto corre durante el
## _ready() del propio sistema, que pasa mientras MapArea todavía está
## armando sus hijos ("Parent node is busy setting up children").
static func make_local_disc(owner: Node3D, map: MapArea, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.set_meta("fill_mat", map.presentation.make_material(Color(color.r, color.g, color.b, color.a * 0.5)))
	mi.set_meta("bord_mat", map.presentation.make_material(Color(
		minf(color.r + 0.3, 1.0), minf(color.g + 0.3, 1.0), minf(color.b + 0.3, 1.0), minf(color.a + 0.3, 1.0))))
	mi.visible = false
	owner.add_child(mi)
	return mi

## Actualiza `preview` con la celda bajo el mouse: oculto si `disc` (el rango)
## no está visible o la celda queda fuera de rango/en un obstáculo; si no,
## snapea a la grilla y sólo redibuja la malla cuando cambió de celda. Devuelve
## el `last_pos` actualizado (quien llama lo guarda para la próxima).
static func update_hover_preview(map: MapArea, disc: MeshInstance3D, preview: MeshInstance3D,
		pos: Vector2, max_range: float, radius: float, last_pos: Vector2,
		fill_color: Color, border_color: Color) -> Vector2:
	if not disc.visible:
		preview.visible = false
		return last_pos
	var in_range := pos.distance_to(map.player_pos) <= max_range \
		and not map.tile_in_obstacle(pos, map.player_elevation)
	if not in_range:
		preview.visible = false
		return last_pos
	var snapped_pos := Vector2(round(pos.x * 2.0) / 2.0, round(pos.y * 2.0) / 2.0)
	if snapped_pos.distance_to(last_pos) > 0.01:
		last_pos = snapped_pos
		preview.set_meta("fill_mat", map.presentation.make_material(fill_color))
		preview.set_meta("bord_mat", map.presentation.make_material(border_color))
		map.presentation.build_tile_disc(preview, snapped_pos, radius, 0.0, 0.015)
	preview.visible = true
	return last_pos
