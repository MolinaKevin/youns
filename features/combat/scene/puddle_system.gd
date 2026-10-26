class_name PuddleSystem
extends Node3D
const CombatEffect := preload("res://features/combat/scene/combat_effect.gd")

## Charcos del combate: colocarlos, que se combinen (charco "lente" donde dos
## reaccionan entre sí), que se evaporen con las rondas, y las consultas que
## usan las cartas (daño/efecto a lo largo de un segmento, charco en una
## celda, etc.).
##
## Vive como hijo de MapArea, que se asigna a sí mismo en `map` antes de
## agregarlo al árbol (ver MapArea._init()) — lo necesita para las mallas
## compartidas (make_mat, build_tile_disc, show_disc_with_los,
## apply_two_surface_mesh, tile_in_obstacle, la
## constante CLICK_MARGIN) y para prender/apagar los árboles cercanos
## (is_tree_near, ignite_trees_in_circle, extinguish_trees_in_circle,
## TREE_VINE_REACH, TREE_VINE_RADIUS_MULT), expuestos por MapArea y sus
## colaboradores.

## Asignado por MapArea antes de add_child(self) — ver MapArea._init().
var map: MapArea

var zones: Array[Dictionary] = []
var _visuals: Array[MeshInstance3D] = []
var _next_id := 0

## Visuales creados para las zonas. Expuesto para que los tests del sistema
## puedan verificar el ciclo de vida sin depender de MapArea.
var visuals: Array[MeshInstance3D]:
	get: return _visuals

var _disc:             MeshInstance3D
var _preview:          MeshInstance3D
var _preview_effect:   String  = CombatEffect.WET
var _preview_radius:   float   = 1.0
var _throw_range:      float   = 0.0
var _preview_last_pos: Vector2 = Vector2(-999.0, -999.0)


func _ready() -> void:
	_disc = PlacementPreview.make_local_disc(self, map, Color(0.1, 0.5, 0.9, 0.45))
	_preview = MeshInstance3D.new()
	_preview.visible = false
	add_child(_preview)


## true mientras se está por tirar un charco (para el "any_disc" de
## MapArea._update_hover()).
func is_placing() -> bool:
	return _disc.visible


func _puddle_base_color(effect: String) -> Color:
	return CombatEffect.puddle_color(effect)

func start_puddle_placement(throw_range: float, effect: String = "wet", puddle_radius: float = 1.0) -> void:
	_throw_range    = throw_range
	_preview_effect = effect
	_preview_radius = puddle_radius
	_preview_last_pos = Vector2(-999.0, -999.0)
	_preview.visible  = false
	var c := _puddle_base_color(effect)
	_disc.set_meta("fill_mat", map.presentation.make_material(Color(c.r, c.g, c.b, 0.22)))
	_disc.set_meta("bord_mat", map.presentation.make_material(Color(
		minf(c.r + 0.3, 1.0), minf(c.g + 0.3, 1.0), minf(c.b + 0.3, 1.0), 0.75)))
	map.presentation.show_disc_with_los(_disc, map.player_pos, throw_range, map.player_elevation)

func clear_puddle_placement() -> void:
	_disc.visible    = false
	_preview.visible = false
	_preview_last_pos = Vector2(-999.0, -999.0)

## Actualiza el preview del tile bajo el mouse mientras se apunta; lo llama
## MapArea._update_hover() con la posición en el mundo ya calculada.
func update_hover_preview(pos: Vector2) -> void:
	var base := _puddle_base_color(_preview_effect)
	_preview_last_pos = PlacementPreview.update_hover_preview(
		map, _disc, _preview, pos, _throw_range, _preview_radius, _preview_last_pos,
		Color(base.r, base.g, base.b, 0.22),
		Color(minf(base.r + 0.2, 1.0), minf(base.g + 0.2, 1.0), minf(base.b + 0.2, 1.0), 0.60))

func _puddle_interaction(a: String, b: String) -> String:
	return CombatEffect.combined_zone_effect(a, b)

## Deja un charco. turns: rondas que dura (0 = no se va nunca; ver
## tick_puddles). damage: daño por turno del estado que causa (0 = el de
## CombatState). Si pisa otro charco con el que reacciona (_puddle_interaction),
## en la intersección queda un charco "lente" con el efecto combinado, que dura
## lo que el más corto de los dos.
##
## Cada zona: {"id", "pos", "radius", "effect", "turns", "damage", "lens",
## "excl"}; excl son los ids de los charcos cuyo disco se recorta del dibujo.
func place_puddle(pos: Vector2, radius: float, effect: String = "wet", turns: int = 0, damage: int = 0) -> void:
	var r2 := float(radius)
	if effect == CombatEffect.VINE and map.interactions.is_tree_near(pos, r2 + map.TREE_VINE_REACH):
		r2 *= map.TREE_VINE_RADIUS_MULT  # las plantas crecen más al lado de un árbol
	var new_id := _next_id
	_next_id += 1
	var new_excl: Array = []
	var to_rebuild: Array[int] = []

	for i in range(zones.size()):
		var existing: Dictionary = zones[i]
		var r1: float  = existing["radius"]
		var c1: Vector2 = existing["pos"]
		var dist: float = c1.distance_to(pos)
		if dist >= r1 + r2:
			continue
		var combined := _puddle_interaction(existing.get("effect", "wet"), effect)
		if combined == "":
			continue

		# El charco existente se redibuja sin la parte que ocupa el nuevo.
		existing["excl"].append(new_id)
		to_rebuild.append(i)

		# Zona de interacción en forma de lente
		var ipos: Vector2  = c1.lerp(pos, r1 / (r1 + r2))
		var ir: float      = maxf(0.5, (r1 + r2 - dist) * 0.5)
		zones.append({
			"id": _next_id, "pos": ipos, "radius": ir, "effect": combined,
			"turns": _shorter_turns(existing["turns"], turns),
			"damage": maxi(existing["damage"], damage), "lens": true, "excl": [],
			"parents": [existing["id"], new_id],
		})
		_next_id += 1
		_add_puddle_visual_lens(c1, r1, pos, r2, combined)

		new_excl.append(existing["id"])

	zones.append({
		"id": new_id, "pos": pos, "radius": r2, "effect": effect,
		"turns": turns, "damage": damage, "lens": false, "excl": new_excl,
	})
	_visuals.append(_make_puddle_visual(pos, r2, effect, _puddle_exclusions(zones.back())))
	for i in to_rebuild:
		_rebuild_puddle_visual(i)
	if effect == CombatEffect.FIRE:
		map.interactions.ignite_trees_in_circle(pos, r2)
	elif effect in [CombatEffect.ICE, CombatEffect.WET]:
		map.interactions.extinguish_trees_in_circle(pos, r2)

## Pasa una ronda: los charcos con duración pierden una y los que llegan a 0
## desaparecen (con sus lentes). Los que los recortaban se redibujan enteros.
func tick_puddles() -> void:
	var removed: Array = []
	for zone in zones:
		if zone["turns"] > 0:
			zone["turns"] -= 1
			if zone["turns"] == 0:
				removed.append(zone["id"])
	if removed.is_empty():
		return
	for i in range(zones.size() - 1, -1, -1):
		if zones[i]["id"] in removed:
			_visuals[i].queue_free()
			_visuals.remove_at(i)
			zones.remove_at(i)
	for i in zones.size():
		var excl: Array = zones[i]["excl"]
		var kept := excl.filter(func(id): return not id in removed)
		if kept.size() != excl.size():
			zones[i]["excl"] = kept
			_rebuild_puddle_visual(i)

## El charco (no combinado) que hay en `pos`, o {} si no hay.
func get_puddle_at(pos: Vector2) -> Dictionary:
	for zone in zones:
		if not zone.get("lens", false) and pos.distance_to(zone["pos"]) <= float(zone["radius"]) + map.CLICK_MARGIN * 0.5:
			return zone
	return {}

## Saca un charco del mapa, con sus zonas combinadas; los que lo recortaban se
## redibujan enteros.
func remove_puddle(zone: Dictionary) -> void:
	var id: int = zone["id"]
	var removed: Array = [id]
	for other in zones:
		if other.get("lens", false) and id in other.get("parents", []):
			removed.append(other["id"])
	for i in range(zones.size() - 1, -1, -1):
		if zones[i]["id"] in removed:
			_visuals[i].queue_free()
			_visuals.remove_at(i)
			zones.remove_at(i)
	for i in zones.size():
		var excl: Array = zones[i]["excl"]
		var kept := excl.filter(func(e): return not e in removed)
		if kept.size() != excl.size():
			zones[i]["excl"] = kept
			_rebuild_puddle_visual(i)

## Traslado de charco: lo saca de donde está y lo deja en `to`, con el mismo
## efecto, radio, rondas que le quedan y daño. Devuelve el charco nuevo.
func move_puddle(zone: Dictionary, to: Vector2) -> Dictionary:
	remove_puddle(zone)
	place_puddle(to, zone["radius"], zone["effect"], zone["turns"], zone["damage"])
	for i in range(zones.size() - 1, -1, -1):
		if not zones[i].get("lens", false):
			return zones[i]
	return {}

## Daño por turno de los estados de los charcos que cruza el segmento:
## {efecto: daño} (el mayor si hay varios); solo charcos con daño propio.
func get_puddle_damage_along(from: Vector2, to: Vector2, contact_margin: float = 0.0) -> Dictionary:
	var result := {}
	if zones.is_empty():
		return result
	for puddle in zones:
		var dmg: int = puddle.get("damage", 0)
		if dmg > 0 and CombatMapQueries.segment_point_distance(from, to, puddle["pos"]) <= puddle["radius"] + contact_margin:
			var effect: String = puddle.get("effect", "wet")
			result[effect] = maxi(int(result.get(effect, 0)), dmg)
	return result

## 0 es "para siempre": gana el otro.
static func _shorter_turns(a: int, b: int) -> int:
	if a == 0:
		return b
	if b == 0:
		return a
	return mini(a, b)

func _puddle_exclusions(zone: Dictionary) -> Array:
	var result: Array = []
	for other in zones:
		if other["id"] in zone["excl"]:
			result.append({"pos": other["pos"], "radius": other["radius"]})
	return result

func _rebuild_puddle_visual(i: int) -> void:
	var zone: Dictionary = zones[i]
	_visuals[i].queue_free()
	_visuals[i] = _make_puddle_visual(zone["pos"], zone["radius"], zone["effect"], _puddle_exclusions(zone))

func _make_puddle_visual(pos: Vector2, radius: float, effect: String = "wet", exclusions: Array = []) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var base := _puddle_base_color(effect)
	mi.set_meta("fill_mat", map.presentation.make_material(Color(base.r, base.g, base.b, 0.35)))
	mi.set_meta("bord_mat", map.presentation.make_material(Color(
		minf(base.r + 0.2, 1.0), minf(base.g + 0.2, 1.0), minf(base.b + 0.2, 1.0), 0.80)))
	add_child(mi)
	map.presentation.build_tile_disc(mi, pos, radius, 0.0, 0.013, exclusions)
	return mi

func _add_puddle_visual_lens(c1: Vector2, r1: float, c2: Vector2, r2: float, effect: String) -> void:
	var mi := MeshInstance3D.new()
	var base := _puddle_base_color(effect)
	mi.set_meta("fill_mat", map.presentation.make_material(Color(base.r, base.g, base.b, 1.0)))
	mi.set_meta("bord_mat", map.presentation.make_material(Color(
		minf(base.r + 0.15, 1.0), minf(base.g + 0.15, 1.0), minf(base.b + 0.15, 1.0), 1.0)))
	add_child(mi)
	_build_lens_disc(mi, c1, r1, c2, r2, 0.016)
	_visuals.append(mi)

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
	map.apply_two_surface_mesh(mi, fill_v, fill_i, bord_v, bord_i)

func is_segment_in_puddle(from: Vector2, to: Vector2) -> bool:
	if zones.is_empty():
		return false
	var steps := maxi(2, int(from.distance_to(to) / 0.3))
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var pos: Vector2 = from.lerp(to, t)
		for puddle in zones:
			if puddle.get("effect", "wet") == "wet" and pos.distance_to(puddle["pos"]) <= puddle["radius"]:
				return true
	return false

func get_puddle_effects_along(from: Vector2, to: Vector2, contact_margin: float = 0.0) -> Dictionary:
	var result := {}
	if zones.is_empty():
		return result
	for puddle in zones:
		if CombatMapQueries.segment_point_distance(from, to, puddle["pos"]) <= puddle["radius"] + contact_margin:
			result[puddle.get("effect", "wet")] = true
	return result

## Cambia el efecto de los charcos que toca el círculo (Chispa: grasa → fuego;
## Escarcha: agua → hielo). Devuelve cuántos cambió.
func convert_puddles(center: Vector2, radius: float, from_effects: Array, to_effect: String) -> int:
	var converted: Array = []
	for i in zones.size():
		var zone: Dictionary = zones[i]
		if not zone.get("effect", "wet") in from_effects:
			continue
		if center.distance_to(zone["pos"]) > radius + float(zone["radius"]):
			continue
		zone["effect"] = to_effect
		if not zone.get("lens", false):
			_rebuild_puddle_visual(i)
		converted.append(zone)
	# El charco nuevo de fuego prende los árboles que toca (y así se propaga).
	for zone in converted:
		if to_effect == "fire":
			map.interactions.ignite_trees_in_circle(zone["pos"], zone["radius"])
		elif to_effect in ["ice", "wet"]:
			map.interactions.extinguish_trees_in_circle(zone["pos"], zone["radius"])
	return converted.size()

## Charcos de esos efectos que toca el segmento (Descarga se propaga por el agua).
func puddles_on_segment(from: Vector2, to: Vector2, effects: Array) -> Array:
	var result: Array = []
	for zone in zones:
		if zone.get("effect", "wet") in effects and CombatMapQueries.segment_point_distance(from, to, zone["pos"]) <= float(zone["radius"]):
			result.append(zone)
	return result
