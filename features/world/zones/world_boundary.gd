extends Node3D

## Cierra el mundo exterior: calcula en una grilla (WorldBoundaryGrid) qué
## parte del suelo es caminable (el suelo de cada zona) y pone paredes
## invisibles en todo su contorno. Lo crea ZoneManager y no depende de qué
## zonas estén cargadas.
##
## El suelo y los árboles de relleno (lo que se ve entre los mapas y alrededor)
## salen de meshes guía de Blender (AutoForest_/AutoGround_/NoAutoFill_/
## NoAutoTrees_, ver AutoDecoration): de los .glb de cada mapa y de
## WorldLayout. Esas guías sólo decoran, no cambian la grilla.
##
## El gym tiene su propio bosque (GymForest): ese rectángulo queda reservado y
## acá no se ponen paredes ni árboles.

const GymForest := preload("res://features/world/zones/gym_forest.gd")
const AutoDecorationScript := preload("res://features/world/zones/auto_decoration.gd")

## Margen de la grilla alrededor de lo caminable (en metros, más 4).
## Zonas de pradera: lo caminable son sus meshes *Meadow (zona -> .glb).
## pradera_norte es el crossroads: sus pasillos llegan al sendero norte del
## hub, a Hub2LeftMeadow de la pradera derecha y a la entrada de left.
## pradera_oeste es left: su claro de la Ladera da contra el pie norte de la
## montaña (la montaña lo corta: ahí van paredes).
## Las praderas nuevas traen además un *ForestFloor: suelo debajo de sus
## propios árboles. No se camina, pero ahí no se plantan árboles generados
## (si no, se encimarían con los del .glb).
## ribera es riverside (detrás del gym, el claro está cerrado por árboles) y
## recodo es bend (sale de la salida de abajo de la pradera derecha): el
## cañón con el río del codo pasa por los dos. playa es beach: abajo, al
## nivel del río, al final del recodo (su *Canyon es sólo el hueco del suelo).
## pinar (pinewood), lomas (hills) y mirador (overlook): praderas al norte de
## la pradera oeste y del crossroads, que terminan en un precipicio (*Canyon).
## meseta es cliffs: una meseta (*Meadow) rodeada por un cañón (*Canyon) con
## un río en el fondo; se entra por el puente natural del este. El cañón no se
## camina (paredes en el borde del precipicio).
## *Rock: roca suelta dentro de una pradera (p. ej. el pasillo de montaña que
## cruza el codo de lado a lado, del cañón a la montaña). No se camina aunque
## tenga pasto debajo (pisa lo caminable).
## Del city_map salen tres cosas para la grilla (ver _city_map_triangles):
## - Ground_West: la franja al pie de la montaña, del otro lado del río. Sigue
##   la curva del río y llega por debajo del agua. Caminable.
## - river_N: el agua del río (va a lo largo de toda la montaña). Paredes en
##   las orillas, sin árboles.
## - Montana_Norte / Montana_Sur / Montana_Cascadas: lo que se levanta más de
##   world_layout.mountain_foot no es caminable (paredes al pie, sin árboles). Si la
##   montaña se abre (las mitades se separan), hay que volver a armar la
##   grilla para que el valle del medio quede caminable. Montana_Cascadas es
##   el macizo que cierra el río al sur: no se abre, y de ahí salen las dos
##   cascadas (Cascada_Hub al río, Cascada_Gym hacia el gym). Sus pozones son
##   river_pool_*, así que cuentan como agua.

var _grid := WorldBoundaryGrid.new()
var _decoration := WorldDecorationBuilder.new()
var _walls := WorldBoundaryWalls.new()
var _walkability := WorldWalkabilityBuilder.new()
var _geometry := WorldGeometryReader.new()
var _layout: WorldLayout = preload("res://data/world/world_layout.tres")
var _settings: WorldGenerationSettings = preload("res://data/world/world_generation_settings.tres")

func build(catalog: ZoneCatalog, force_procedural_decoration := false) -> void:
	var started_at := Time.get_ticks_msec()
	var checkpoint := started_at
	if DebugSettings.verbose_logging_enabled:
		print("[WorldBoundary] Construyendo límites y decoración global…")
	for error_text in _layout.validate(catalog): push_error("WorldLayout: " + error_text)
	checkpoint = _log_build_step("Validación de configuración", started_at, checkpoint)
	_decoration.prepare(force_procedural_decoration)
	_geometry.configure(_layout, _decoration)
	var hub_offset := catalog.definition(_layout.hub_id).offset
	var walkable_rects: Array[Rect2] = []
	walkable_rects.append(_offset_rect(_layout.hub_ground, hub_offset))
	walkable_rects.append(_layout.north_trail)
	var placeholder_rects := {}
	for id in _layout.placeholder_zones:
		var o := catalog.definition(id).offset
		placeholder_rects[id] = Rect2(o.x - _layout.placeholder_size * 0.5, o.z - _layout.placeholder_size * 0.5, _layout.placeholder_size, _layout.placeholder_size)
		walkable_rects.append(placeholder_rects[id])
	var hub_bridge := _offset_rect(_layout.hub_bridge, hub_offset)
	var meadows := {}   # zona -> triángulos de sus *Meadow
	var floor_tris := PackedVector2Array()   # *ForestFloor y *Canyon de todas las praderas
	var rock_tris := PackedVector2Array()    # *Rock: tapa también lo caminable
	for id in _layout.meadow_maps:
		var found := _geometry.meadow_triangles(_layout.meadow_maps[id], catalog.definition(id).offset)
		meadows[id] = found["meadow"]
		floor_tris.append_array(found["floor"])
		floor_tris.append_array(found["canyon"])
		rock_tris.append_array(found["rock"])
		checkpoint = _log_build_step("Lectura del mapa " + id, started_at, checkpoint)
	var meadow_tris := PackedVector2Array()
	for id in meadows:
		meadow_tris.append_array(meadows[id])
	var city := _geometry.city_triangles(hub_offset)
	checkpoint = _log_build_step("Lectura de city_map", started_at, checkpoint)
	var west_tris: PackedVector2Array = city["west"]
	var water_tris: PackedVector2Array = city["water"]
	var mountain_tris: PackedVector2Array = city["mountain"]

	var gym_forest: Node = GymForest.new()
	var gym_rect: Rect2 = _offset_rect(gym_forest.covered_rect(), catalog.definition(_layout.gym_id).offset)
	gym_forest.free()
	checkpoint = _log_build_step("Preparación del bosque del gym", started_at, checkpoint)

	_grid = _walkability.build(_layout, hub_offset, gym_rect, walkable_rects, placeholder_rects, hub_bridge, meadows, meadow_tris, floor_tris, rock_tris, west_tris, water_tris, mountain_tris, _settings.forest_depth + 4)
	checkpoint = _log_build_step("Construcción de la grilla caminable", started_at, checkpoint)
	_walls.build(self, _grid, _layout, _settings.wall_height)
	checkpoint = _log_build_step("Construcción de paredes", started_at, checkpoint)
	_decoration.build(self, _grid, _layout, catalog, _settings.tree_clearance, _settings.tree_spacing, _settings.tree_seed)
	_log_build_step("Decoración y árboles", started_at, checkpoint)

func _offset_rect(r: Rect2, offset: Vector3) -> Rect2:
	return Rect2(r.position + Vector2(offset.x, offset.z), r.size)


func _log_build_step(step: String, started_at: int, previous_at: int) -> int:
	var now := Time.get_ticks_msec()
	if DebugSettings.verbose_logging_enabled:
		print("[WorldBoundary] %s: +%d ms (total: %d ms)" % [step, now - previous_at, now - started_at])
	return now

## Tipo de celda de la grilla en ese punto (WorldBoundaryGrid.EMPTY, WALKABLE...).
func cell_type_at(pos: Vector3) -> int:
	return _grid.cell_type_at(pos)

# ── Zonas (fachada de WorldBoundaryGrid) ─────────────────────────────────────

## En qué zona está ese punto del mundo (clave de ZoneManager.catalog).
func zone_at(pos: Vector3) -> String:
	return _grid.zone_at(pos)


## Ruta segura para el Youn del grupo. Sólo usa el suelo que la misma grilla
## considera transitable, por lo que evita cañones, ríos y rocas.
func find_walkable_path(from: Vector3, to: Vector3) -> Array[Vector2]:
	return _grid.find_walkable_path(from, to)

func get_map_bounds() -> Rect2:
	return _grid.get_map_bounds()

func get_map_zone_edges() -> Array[Dictionary]:
	return _grid.get_map_zone_edges()

func get_map_zone_centers() -> Dictionary:
	return _grid.get_map_zone_centers()

## El camino de tierra del sendero norte se ve sólo cuando está abierto
## (cerrado, lo tapan los árboles del hub; el suelo sigue teniendo colisión).
func set_north_trail_open(open: bool) -> void:
	_walls.set_trail_visible(self, open)

## Dónde quedaron los árboles de relleno (para tests y depuración).
func decoration_tree_positions() -> Array[Vector3]:
	return _decoration.tree_positions()
