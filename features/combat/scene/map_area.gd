class_name MapArea
extends Node3D

## Charcos, trampas, granadas, salto de roca, árboles y módulos: estado y
## lógica en su propio componente (ver puddle_system.gd/trap_system.gd/
## grenade_system.gd/rock_jump_system.gd/tree_system.gd/module_system.gd). Se
## crean y se parentean acá mismo (no en _ready) para que funcionen incluso en
## los tests que instancian MapArea suelto, sin agregarlo al árbol.
var _puddle_system    := PuddleSystem.new()
var _trap_system      := TrapSystem.new()
var _grenade_system   := GrenadeSystem.new()
var _rock_jump_system := RockJumpSystem.new()
var _tree_system       := TreeSystem.new()
var _module_system     := ModuleSystem.new()
var _overlay           := CombatMapOverlay.new()
var _input_controller  := CombatMapInput.new()
var _navigation         := CombatNavigation.new()
var _queries            := CombatMapQueries.new()
var _actor_mover        := CombatActorMover.new()
var _spell_system       := CombatSpellSystem.new()
var _terrain            := CombatTerrain.new()
var _targeting          := CombatTargeting.new()
var _push_system        := CombatPushSystem.new()
var _overwatch_system   := CombatOverwatchSystem.new()
var _renderer           := CombatMapRenderer.new()
var _range_overlay      := CombatRangeOverlay.new()
var _actor_presentation := CombatActorPresentation.new()

## Alias para que `map.LOG_SEGMENTS` (lo usan los tests) siga andando con el
## dueño real del dato movido a TreeSystem.
const LOG_SEGMENTS := TreeSystem.LOG_SEGMENTS

func _init() -> void:
	add_child(_overlay)
	_input_controller.map = self
	_input_controller.position_selected.connect(func(pos): position_selected.emit(pos))
	add_child(_input_controller)
	_terrain.configure(WORLD_W, WORLD_H)
	_navigation.configure(_terrain, WORLD_W, WORLD_H)
	_queries.map = self
	_actor_mover.map = self
	_actor_mover.enemy_reached_target.connect(func(): enemy_reached_target.emit())
	_spell_system.map = self
	_targeting.map = self
	_push_system.map = self
	_overwatch_system.map = self
	_range_overlay.terrain = _terrain
	_range_overlay.queries = _queries
	_range_overlay.renderer = _renderer
	_actor_presentation.map = self
	_puddle_system.map = self
	add_child(_puddle_system)
	_trap_system.map = self
	add_child(_trap_system)
	_grenade_system.map = self
	add_child(_grenade_system)
	_rock_jump_system.map = self
	add_child(_rock_jump_system)
	_tree_system.map = self
	add_child(_tree_system)
	_module_system.map = self
	_module_system.tree_system = _tree_system
	add_child(_module_system)
	setup_biome(null)

signal position_selected(pos: Vector2)
signal player_anim_finished
signal enemy_anim_finished
signal enemy_reached_target
## Se prendió fuego el árbol al que está trepado el jugador (ya bajó al pie).
signal player_knocked_off_tree(burning: bool)

# ── World bounds ──────────────────────────────────────────────────────────────
const WORLD_W := 30.0
const WORLD_H := 30.0

const DEFAULT_BIOME: BiomeData = preload("res://data/biomes/pradera.tres")

## Bioma que suministra el layout del combate actual.
var biome: BiomeData

func setup_biome(value: BiomeData) -> void:
	biome = value if value != null else DEFAULT_BIOME
	biome.setup_combat_map(self)

# ── Positions (XZ world space) ────────────────────────────────────────────────
var player_pos := Vector2(3.0, 27.0)
var enemy_pos  := Vector2(27.0, 3.0)

# ── Shared combat state ───────────────────────────────────────────────────────
var _enemy_move_pending:
	get: return _actor_mover.enemy_move_pending
	set(value): _actor_mover.enemy_move_pending = value
var _enemy_waypoints: Array[Vector3]:
	get: return _actor_mover.enemy_waypoints
## Reenvío a PuddleSystem (compat con combat_player_actions.gd/combat_enemy_ai.gd/tests).

# ── Elevation ─────────────────────────────────────────────────────────────────
# 0 = suelo, 1 = encima de una plataforma
var player_elevation: int = 0
var enemy_elevation:  int = 0

# ── Pathfinding ───────────────────────────────────────────────────────────────
var _last_path: Array[Vector2]:
	get: return _navigation.last_path
var _player_waypoints: Array[Vector3]:
	get: return _actor_mover.player_waypoints
# ── Obstacles ─────────────────────────────────────────────────────────────────
# type "solid"  → bloquea movimiento Y línea de visión
# type "rock"   → bloquea movimiento, LOS pasa a través (piedra pequeña)
# type "bridge" → movimiento permitido por debajo, LOS bloqueada (puente)
# "module": true → es un módulo: se puede romper, golpear y saltar desde él
#                  (las piedras chicas; las cartas crean más, ver build_modules)
## Lo provee el CombatBiomeLayout; CombatTerrain conserva e interpreta esa
## geometría durante el combate.
var solid_obstacles: Array[Dictionary]:
	get: return _terrain.obstacles

## ── API de construcción de biomas ────────────────────────────────────────────
## CombatBiomeLayout usa estos métodos en vez de depender del formato interno
## de `solid_obstacles`. Los elementos agregados acá son el estado inicial;
## durante el combate los sistemas pueden mutarlos o agregar módulos propios.
func clear_biome_obstacles() -> void:
	_terrain.clear()

func add_solid(pos: Vector2, radius: float) -> void:
	_terrain.add({"pos": pos, "radius": radius, "type": "solid"})

func add_solid_box(pos: Vector2, size: Vector2) -> void:
	_terrain.add({"pos": pos, "box": size, "type": "solid"})

func add_rock(pos: Vector2, radius: float, module: bool = true) -> void:
	_terrain.add({"pos": pos, "radius": radius, "type": "rock", "module": module})

func add_bridge(pos: Vector2, size: Vector2) -> void:
	_terrain.add({"pos": pos, "box": size, "type": "bridge"})

func add_tree(pos: Vector2, radius: float = 0.6) -> void:
	_terrain.add({"pos": pos, "radius": radius, "type": "tree"})

func add_platform(pos: Vector2, size: Vector2, ramps: Array[Dictionary] = []) -> void:
	_terrain.add({"pos": pos, "box": size, "type": "platform", "ramps": ramps.duplicate(true)})

const PLATFORM_HEIGHT := 1.5
const TREE_HEIGHT     := 2.4
const RAMP_DEPTH      := 1.5

# ── Visual ────────────────────────────────────────────────────────────────────
## Alturas de los resaltados sobre el suelo: la sombra está en 0.02.
const HIGHLIGHT_Y := 0.03
const HOVER_Y := 0.04
## Un área tiene que cubrir este tramo del radio de la huella para afectarla.
## Las colisiones físicas conservan el radio completo.
const AREA_CONTACT_FRACTION := 1.0 / 3.0
## Cuánto más allá de la huella un clic sigue contando como "sobre el personaje".
const CLICK_MARGIN := 0.6

var _move_disc: MeshInstance3D:
	get: return _overlay.move_disc
var _player_circle: MeshInstance3D:
	get: return _overlay.player_circle
var _attack_disc: MeshInstance3D:
	get: return _overlay.attack_disc
var _dest_marker: MeshInstance3D:
	get: return _overlay.dest_marker
var _path_highlight: MeshInstance3D:
	get: return _overlay.path_highlight
var _hover_cell: MeshInstance3D:
	get: return _overlay.hover_cell
var _player_shadow: MeshInstance3D:
	get: return _overlay.player_shadow
var _enemy_shadow: MeshInstance3D:
	get: return _overlay.enemy_shadow
var _player_shadow_radius: float = 0.4
var _enemy_shadow_radius:  float = 0.4
## Vista 3D + nodo de posición/rotación de cada personaje (ver combat_actor_view.gd).
var _player_view: CombatActorView
var _enemy_view:  CombatActorView
var _player_rotate_speed: float = 8.0
var _enemy_rotate_speed:  float = 8.0

const _PRIORITY_ANIMS: Array[String]       = ["attack", "range", "damage", "die"]
const _ENEMY_PRIORITY_ANIMS: Array[String] = ["attack", "damage"]

# ── Movement animation ────────────────────────────────────────────────────────
const ACTOR_MOVE_SPEED  := 12.0
const MIN_SEPARATION    := 0.8

var _player_target: Vector3
var _enemy_target:  Vector3

var _enemy_highlight: MeshInstance3D:
	get: return _overlay.enemy_highlight
var _self_highlight: MeshInstance3D:
	get: return _overlay.self_highlight
var _enemy_hover: MeshInstance3D:
	get: return _overlay.enemy_hover
var _self_hover: MeshInstance3D:
	get: return _overlay.self_hover
var _push_disc: MeshInstance3D:
	get: return _overlay.push_disc
var _push_enemy_disc: MeshInstance3D:
	get: return _overlay.push_enemy_disc
var _card_pattern_preview: MeshInstance3D:
	get: return _overlay.card_pattern_preview
var _overwatch_zone: MeshInstance3D:
	get: return _overlay.overwatch_zone
var _overwatch_preview_disc: MeshInstance3D:
	get: return _overlay.overwatch_preview_disc

# ── Init ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_setup_ground()
	_overlay.setup()

	biome.build_combat_map(self)
	_setup_actors()

func _setup_ground() -> void:
	add_child(_renderer.make_ground(WORLD_W, WORLD_H))

func _make_mat(color: Color) -> StandardMaterial3D:
	return _overlay.make_material(color)

func _make_disc(color: Color) -> MeshInstance3D:
	return _overlay.make_disc(color)

func _show_disc(mi: MeshInstance3D, center: Vector2, radius: float) -> void:
	_renderer.show_disc(mi, center, radius)

func _show_simple_disc(mi: MeshInstance3D, center: Vector2, radius: float) -> void:
	_renderer.show_simple_disc(mi, center, radius)

func _build_tile_disc(mi: MeshInstance3D, center: Vector2, radius: float, inner_radius: float, y: float, exclusions: Array = []) -> void:
	_renderer.build_tile_disc(mi, center, radius, inner_radius, y, exclusions)

## Pinta las casillas de la huella de un personaje (las mismas de su sombra).
func _show_footprint(mi: MeshInstance3D, center: Vector2, radius: float, y := HIGHLIGHT_Y) -> void:
	_renderer.show_footprint(mi, center, radius, y)


func _setup_actors() -> void:
	_actor_presentation.setup_actors()

func setup_player(data: YounData) -> void:
	_actor_presentation.setup_player(data)

func play_player_anim(anim_key: String) -> void:
	_player_view.play(anim_key)

func setup_enemy_youn(data: YounData) -> void:
	_actor_presentation.setup_enemy(data)

func play_enemy_anim(anim_key: String) -> void:
	_enemy_view.play(anim_key)

func _update_actor_positions() -> void:
	var player_y: float = _terrain.player_height_at(player_pos, player_elevation)
	_player_target = Vector3(player_pos.x, player_y, player_pos.y)
	if not _tree_system._climbed_tree.is_empty():
		# Arriba del árbol: solo cambia lo que se ve; la posición lógica queda al pie.
		var t: Vector2 = _tree_system._climbed_tree["pos"]
		_player_target = Vector3(t.x, TREE_HEIGHT, t.y)
	var enemy_y: float = float(enemy_elevation) * PLATFORM_HEIGHT
	_enemy_target  = Vector3(enemy_pos.x, enemy_y, enemy_pos.y)

func _process(delta: float) -> void:
	_warm_grid_caches()
	_actor_mover.update(delta)

func lock_hover_at_last_click() -> void:
	_input_controller.lock_hover_at_last_click()

func unlock_hover() -> void:
	_input_controller.unlock_hover()

func set_status_texts(player_text: String, enemy_text: String) -> void:
	_actor_presentation.set_status_texts(player_text, enemy_text)

func _place_status_labels() -> void:
	_actor_presentation.place_status_labels()

func _update_hover_at(pos: Vector2) -> void:
	_targeting.update_hover(pos)

func _clear_hover() -> void:
	_targeting.clear_hover()

func _show_single_cell(mi: MeshInstance3D, world_pos: Vector2) -> void:
	var center := _renderer.visual_cell_center(world_pos)
	_renderer.show_single_cell(mi, center, _terrain.height_at(center))

# ── Helpers ───────────────────────────────────────────────────────────────────
func movement_distance(a: Vector2, b: Vector2) -> float:
	return a.distance_to(b)

# ── Terrain (fachada de CombatTerrain) ─────────────────────────────────────────
func _elevation_at(pos: Vector2) -> int:
	return _terrain.elevation_at(pos)

# ── Move ──────────────────────────────────────────────────────────────────────
func start_move_selection(move_range: float) -> void:
	_targeting.start_move_selection(move_range)


func _tile_in_obstacle(pos: Vector2, elevation: int = 0) -> bool:
	return _terrain.tile_in_obstacle(pos, elevation)

func _apply_two_surface_mesh(mi: MeshInstance3D,
		fv: PackedVector3Array, fi: PackedInt32Array,
		bv: PackedVector3Array, bi: PackedInt32Array) -> void:
	_renderer.apply_two_surface_mesh(mi, fv, fi, bv, bi)

func clear_move_selection() -> void:
	_targeting.clear_move_selection()

func show_move_preview(pos: Vector2) -> void:
	_targeting.show_move_preview(pos)

func clear_move_preview() -> void:
	_targeting.clear_move_preview()

func show_path_preview() -> void:
	_targeting.show_path_preview()

func _render_path_preview() -> void:
	_range_overlay.render_path_preview(_path_highlight, _last_path)

func clear_path_preview() -> void:
	_targeting.clear_path_preview()

func try_move_player_to(pos: Vector2) -> bool:
	var goal := CombatGrid.to_cell(pos)
	var path := _navigation.path_for_move(pos)
	if path.size() < 2:
		return false
	var from_elevation := player_elevation
	player_pos       = CombatGrid.to_world(goal)
	player_elevation = _elevation_at(player_pos)
	# El personaje recorre el camino esquina por esquina.
	_player_waypoints.clear()
	for cell in CombatGrid.corners(path).slice(1):
		var w := CombatGrid.to_world(cell)
		_player_waypoints.append(Vector3(w.x, _terrain.player_height_at(w, maxi(from_elevation, _elevation_at(w))), w.y))
	_navigation.clear_planned_path()
	clear_move_selection()
	_update_actor_positions()
	if not _player_waypoints.is_empty():
		_player_waypoints[-1] = _player_target
	return true

func get_path_cost() -> float:
	return _navigation.last_path_cost

## Prepara el movimiento del jugador hacia pos dentro de la selección actual.
## Devuelve "" si se puede (y deja el camino listo para show_path_preview),
## o el motivo: "range", "blocked" o "no_path".
func plan_player_move(pos: Vector2) -> String:
	return _navigation.plan_move(pos, player_elevation, _player_shadow_radius, enemy_pos, _enemy_shadow_radius)

## Llena de a poco los cachés de altura y de obstáculos (con las huellas de
## ambos personajes) para que el primer movimiento no tenga un tirón.
func _warm_grid_caches() -> void:
	_terrain.warm_caches(_player_shadow_radius, _enemy_shadow_radius)

## Dibuja las casillas dadas apoyadas sobre el terreno (cada una a su altura).
## Arreglos pre-dimensionados: con alcances grandes son decenas de miles de casillas.
func _build_cells_on_terrain(mi: MeshInstance3D, cells: Array) -> void:
	_range_overlay.build_cells_on_terrain(mi, cells)

## true si un círculo de radio `margin` en wp choca con obstáculos al nivel `elevation`.
func _pos_blocked(wp: Vector2, elevation: int = 0, margin: float = CombatTerrain.PATH_CELL * 0.5) -> bool:
	return _terrain.pos_blocked(wp, elevation, margin)

# ── Attack ────────────────────────────────────────────────────────────────────
func start_attack_selection(attack_range: float) -> void:
	_targeting.start_attack_selection(attack_range)

func clear_attack_selection() -> void:
	_targeting.clear_attack_selection()


## Vista previa y comprobación compartida de CardPattern. Las coordenadas y
## tamaños ya llegan en unidades de mundo; los módulos se resuelven en la
## línea de acción antes de llamar acá.
func show_card_pattern_preview(pattern: CardPattern, origin: Vector2, direction: Vector2, primary: float) -> void:
	_targeting.show_card_pattern_preview(pattern, origin, direction, primary)


func clear_card_pattern_preview() -> void:
	_targeting.clear_card_pattern_preview()


func is_enemy_in_card_pattern(pattern: CardPattern, origin: Vector2, direction: Vector2, primary: float) -> bool:
	return _targeting.is_enemy_in_card_pattern(pattern, origin, direction, primary)


func _build_line_pattern(mi: MeshInstance3D, origin: Vector2, direction: Vector2, length: float, width: float, start_offset: float) -> void:
	_renderer.build_line_pattern(mi, origin, direction, length, width, start_offset,
		_make_mat(Color(0.95, 0.65, 0.15, 0.35)))

## Distancia entre los bordes de las huellas del jugador y del enemigo.
func actors_gap() -> float:
	return _queries.actors_gap()

## El alcance se mide entre los bordes de las huellas: con huellas circulares
## los centros nunca quedan a menos de la suma de los radios. Media casilla de
## tolerancia porque las posiciones caen en centros de casilla.
func is_enemy_in_attack_range(attack_range: float) -> bool:
	return _queries.is_enemy_in_attack_range(attack_range)

func is_enemy_in_melee_range() -> bool:
	return _queries.is_enemy_in_melee_range()

func is_player_in_melee_range() -> bool:
	return _queries.is_player_in_melee_range()

# ── LOS ───────────────────────────────────────────────────────────────────────
# LOS para ataques de rango: rocas transparentes, puentes opacos.
func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	return _queries.has_line_of_sight(from, to)

# ── Target highlights ─────────────────────────────────────────────────────────
func start_enemy_highlight() -> void:
	_targeting.start_enemy_highlight()

func clear_enemy_highlight() -> void:
	_targeting.clear_enemy_highlight()

func start_self_highlight() -> void:
	_targeting.start_self_highlight()

func clear_self_highlight() -> void:
	_targeting.clear_self_highlight()

## Un clic "toca" a un personaje si cae sobre su huella o cerca (CLICK_MARGIN).
func is_click_on_enemy(pos: Vector2) -> bool:
	return _targeting.is_click_on_enemy(pos)

func is_click_on_player(pos: Vector2) -> bool:
	return _targeting.is_click_on_player(pos)

## Mueve al enemigo hasta la casilla alcanzable más cercana a target.
func move_enemy_toward(target: Vector2, move_range: float) -> bool:
	var route := _navigation.find_toward(enemy_pos, target, move_range, enemy_elevation,
		_enemy_shadow_radius, player_pos, _player_shadow_radius)
	if route.is_empty():
		return false
	_enemy_waypoints.clear()
	for cell in CombatGrid.corners(route["path"]).slice(1):
		var w := CombatGrid.to_world(cell)
		_enemy_waypoints.append(Vector3(w.x, float(_elevation_at(w)) * PLATFORM_HEIGHT, w.y))
	enemy_pos       = route["destination"]
	enemy_elevation = _elevation_at(enemy_pos)
	_update_actor_positions()
	return true

# ── Traps (estado y lógica en trap_system.gd) ──────────────────────────────────
func start_trap_placement(trap_range: float, trap_radius: float = 1.0, previsualize_line_of_sight := true) -> void:
	_trap_system.start_trap_placement(trap_range, trap_radius, previsualize_line_of_sight)

func _show_disc_with_los(mi: MeshInstance3D, origin: Vector2, radius: float, elevation: int = 0, block_rocks: bool = false, block_bridges: bool = true) -> void:
	_range_overlay.show_disc_with_los(mi, origin, radius, elevation, block_rocks, block_bridges)

func clear_trap_placement() -> void:
	_trap_system.clear_trap_placement()

func place_trap(pos: Vector2, radius: float, damage: int, card_name: String) -> void:
	_trap_system.place_trap(pos, radius, damage, card_name)

func check_and_trigger_traps(unit_pos: Vector2, contact_margin: float = 0.0) -> int:
	return _trap_system.check_and_trigger_traps(unit_pos, contact_margin)

func check_and_trigger_traps_along_path(_from: Vector2, to: Vector2, contact_margin: float = 0.0) -> int:
	return _trap_system.check_and_trigger_traps_along_path(_from, to, contact_margin)

# ── Grenade (estado y lógica en grenade_system.gd) ─────────────────────────────
func calculate_grenade_landing(from: Vector2, target: Vector2, bounce: float) -> Vector2:
	return _grenade_system.calculate_landing(from, target, bounce)

# Returns the point where the segment from→to first hits an obstacle, or to if clear.
func _clip_path_at_obstacle(from: Vector2, to: Vector2) -> Vector2:
	return _queries.clip_path_at_obstacle(from, to)

func show_grenade_preview(landing: Vector2, aoe_radius: float) -> void:
	_grenade_system.show_preview(landing, aoe_radius)

func clear_grenade_preview() -> void:
	_grenade_system.clear_preview()

func is_enemy_in_explosion(center: Vector2, radius: float) -> bool:
	return _grenade_system.is_enemy_in_explosion(center, radius)

# ── Rock Jump (estado y lógica en rock_jump_system.gd) ─────────────────────────
func get_rocks_in_range(origin: Vector2, max_range: float) -> Array[Dictionary]:
	return _rock_jump_system.get_rocks_in_range(origin, max_range)

func start_rock_jump_selection(jump_range: float) -> void:
	_rock_jump_system.start_rock_jump_selection(jump_range)

func get_rock_near(pos: Vector2) -> Dictionary:
	return _rock_jump_system.get_rock_near(pos)

func start_jump_landing_selection(rock_pos: Vector2, landing_range: float) -> void:
	_rock_jump_system.start_jump_landing_selection(rock_pos, landing_range)

## Indica si una acción de salto puede terminar en esta celda. La comprobación
## espacial pertenece al mapa; las reglas de la carta viven en PlayerActions.
func can_jump_land_at(pos: Vector2) -> bool:
	return not _terrain.tile_in_obstacle(pos, 0)

## Actualiza la posición lógica y visual del jugador al terminar un salto.
func land_player_from_jump(pos: Vector2) -> void:
	player_pos = pos
	player_elevation = _terrain.elevation_at(pos)
	_update_actor_positions()

func clear_rock_jump_selection() -> void:
	_rock_jump_system.clear_rock_jump_selection()

func is_enemy_near_pos(pos: Vector2, radius: float) -> bool:
	return _rock_jump_system.is_enemy_near_pos(pos, radius)

# ── Push ──────────────────────────────────────────────────────────────────────
func start_push_enemy_selection(grab_range: float) -> void:
	_push_system.start_enemy_selection(grab_range)

func start_push_cone(push_range: float) -> void:
	_push_system.start_enemy_cone(push_range)

func clear_push_selection() -> void:
	_push_system.clear_selection()

func is_pos_in_push_cone(pos: Vector2, push_range: float) -> bool:
	return _push_system.is_pos_in_enemy_cone(pos, push_range)

func _build_cone_disc(mi: MeshInstance3D, origin: Vector2, direction: Vector2, max_range: float, half_angle_deg: float) -> void:
	_renderer.build_cone_disc(mi, origin, direction, max_range, half_angle_deg)

func calculate_push_landing(direction_target: Vector2, push_range: float) -> Vector2:
	return _push_system.calculate_push_landing(direction_target, push_range)

## Tirón y ancla: el enemigo se arrastra hacia `toward` hasta `distance`
## (sin pasarse) y se frena en los obstáculos. push_enemy_to además lo deja a
## distancia mínima del jugador.
func calculate_drag_landing(toward: Vector2, distance: float) -> Vector2:
	return _push_system.calculate_drag_landing(toward, distance)

# ── Módulos (estado y lógica en module_system.gd) ──────────────────────────────
static func is_module(obs: Dictionary) -> bool:
	return ModuleSystem.is_module(obs)

## Muestra el alcance (romper, golpear o crear) alrededor del jugador.
func start_module_selection(reach: float) -> void:
	_module_system.start_module_selection(reach)

func clear_module_selection() -> void:
	_module_system.clear_module_selection()

## Derrumbe: resalta al enemigo y el alcance.
func start_collapse_selection(reach: float) -> void:
	_module_system.start_collapse_selection(reach)

## Lanzar módulo: muestra hasta dónde se puede tirar.
func start_module_throw_target(throw_range: float) -> void:
	_module_system.start_module_throw_target(throw_range)

## Módulos pegados al enemigo (los que le caen encima con un derrumbe).
func modules_adjacent_to_enemy() -> Array:
	return _module_system.modules_adjacent_to_enemy()

## Derrumbe: los módulos pegados al enemigo se le caen encima y se rompen.
## Devuelve cuántos fueron.
func collapse_modules_on_enemy() -> int:
	return _module_system.collapse_modules_on_enemy()

## Lanza el módulo a `target` (vuela por encima de todo): al caer se rompe y le
## pega a quien esté ahí. Devuelve {"enemy": bool, "player": bool}.
func throw_module(obs: Dictionary, target: Vector2) -> Dictionary:
	return _module_system.throw_module(obs, target)

## El módulo bajo `pos` (o {} si no hay).
func get_module_at(pos: Vector2) -> Dictionary:
	return _module_system.get_module_at(pos)

## Distancia del jugador al borde del obstáculo, contando desde su huella.
func obstacle_gap(obs: Dictionary) -> float:
	return _module_system.obstacle_gap(obs)

## Lo usa CombatBiomeLayout para construir la malla inicial de una roca del
## layout, sin conocer el formato interno de ModuleSystem.
func build_initial_rock_mesh(mi: MeshInstance3D, obs: Dictionary, pos: Vector2, rock_mat: StandardMaterial3D) -> void:
	_module_system.build_initial_rock_mesh(mi, obs, pos, rock_mat)

## Levanta hasta `count` módulos en fila, centrada en `center` y perpendicular
## a la línea jugador → center (un muro de frente). Los lugares ocupados (por
## un actor, otro obstáculo o fuera del mapa) se saltean. Devuelve cuántos creó.
func build_modules(center: Vector2, count: int) -> int:
	return _module_system.build_modules(center, count)

## Rompe `first` y los módulos pegados a él (los más cercanos primero), hasta
## `count` en total. Devuelve cuántos rompió.
func break_modules(first: Dictionary, count: int) -> int:
	return _module_system.break_modules(first, count)

## Golpe de módulo: lo desliza en `dir` hasta `distance` o hasta chocar con un
## actor u otro obstáculo. Un tramo de tronco arrastra al tronco entero (ariete).
## Si choca un árbol con el jugador arriba, lo tira.
## Devuelve {"hit": "enemy" | "player" | "", "pos": Vector2, "tree": Dictionary}.
func slide_module(obs: Dictionary, dir: Vector2, distance: float) -> Dictionary:
	return _module_system.slide_module(obs, dir, distance)

## Cono de dirección para golpear un módulo: se aleja del jugador.
func start_module_push_cone(module_pos: Vector2, push_range: float, half_angle: float = 55.0) -> void:
	_push_system.start_module_cone(module_pos, push_range, half_angle)

func is_pos_in_module_cone(module_pos: Vector2, pos: Vector2, push_range: float, half_angle: float = 55.0) -> bool:
	return _push_system.is_pos_in_module_cone(module_pos, pos, push_range, half_angle)

## Los obstáculos cambiaron: se recalculan los bloqueos (caminos y selección).
func _obstacles_changed() -> void:
	_terrain.invalidate()

# ── Hechizos ──────────────────────────────────────────────────────────────────
## Zonas marcadas que caen al terminar la ronda en la que llegan a 0 rondas
## (Meteoro, Granizada...). El estado vive en CombatSpellSystem.
var delayed_zones: Array[Dictionary]:
	get: return _spell_system.delayed_zones

## Hechizos a un punto: muestra el alcance alrededor del jugador.
func start_spell_selection(spell_range: float) -> void:
	_spell_system.start_selection(spell_range)

func clear_spell_selection() -> void:
	_spell_system.clear_selection()

static func is_pos_in_zones(pos: Vector2, zones: Array) -> bool:
	return CombatMapQueries.is_pos_in_zones(pos, zones)

func is_enemy_in_zones(zones: Array) -> bool:
	return _queries.is_enemy_in_zones(zones)

func is_player_in_zones(zones: Array) -> bool:
	return _queries.is_player_in_zones(zones)

## El segmento pasa por la huella del enemigo (rayos en línea).
func segment_hits_enemy(from: Vector2, to: Vector2) -> bool:
	return _queries.segment_hits_enemy(from, to)

## El enemigo está dentro del cono (se cuenta su huella).
func is_enemy_in_cone(origin: Vector2, dir: Vector2, cone_range: float, half_angle_deg: float) -> bool:
	return _queries.is_enemy_in_cone(origin, dir, cone_range, half_angle_deg)

## Contacto mínimo de un área: un tercio del radio de la huella. No se usa
## para choques físicos, sólo para charcos, explosiones, líneas y conos.
func player_area_contact_radius() -> float:
	return _queries.player_area_contact_radius()

func enemy_area_contact_radius() -> float:
	return _queries.enemy_area_contact_radius()

func is_enemy_in_area_circle(center: Vector2, radius: float) -> bool:
	return _queries.is_enemy_in_area_circle(center, radius)

func is_player_in_area_circle(center: Vector2, radius: float) -> bool:
	return _queries.is_player_in_area_circle(center, radius)

## El enemigo queda dentro del círculo físico completo (movimiento/choques).
func is_enemy_in_circle(center: Vector2, radius: float) -> bool:
	return _queries.is_enemy_in_circle(center, radius)

func is_player_in_circle(center: Vector2, radius: float) -> bool:
	return _queries.is_player_in_circle(center, radius)

## Meteoro y compañía: marca la zona. Cae en resolve_delayed_zones cuando
## pasan `rounds` rondas; si effect no es "", deja ese charco.
func place_delayed_zone(pos: Vector2, radius: float, damage: int, zone_name: String,
		rounds: int = 1, effect: String = "", puddle_turns: int = 0) -> void:
	_spell_system.place_delayed_zone(pos, radius, damage, zone_name, rounds, effect, puddle_turns)

## Pasa una ronda: caen las zonas que llegan a 0. Devuelve las que cayeron:
## [{"name", "damage", "effect", "tick_damage", "enemy": bool, "player": bool}].
## Las que cayeron dejan su charco.
func resolve_delayed_zones() -> Array:
	return _spell_system.resolve_delayed_zones()

## Parpadeo: se puede aparecer ahí (dentro del mapa, sin obstáculo y sin pisar
## al enemigo). Ignora lo que haya en el camino.
func can_blink_to(pos: Vector2) -> bool:
	if pos.x < 0.0 or pos.y < 0.0 or pos.x > WORLD_W or pos.y > WORLD_H:
		return false
	if pos.distance_to(enemy_pos) < MIN_SEPARATION:
		return false
	return not _pos_blocked(pos, _elevation_at(pos), _player_shadow_radius)

func blink_player_to(pos: Vector2) -> void:
	player_pos = pos
	player_elevation = _elevation_at(pos)
	_update_actor_positions()

# ── Árboles (estado y lógica en tree_system.gd) ────────────────────────────────
## El árbol bajo `pos` (o {} si no hay).
func get_tree_at(pos: Vector2) -> Dictionary:
	return _tree_system.get_tree_at(pos)

static func is_tree_burning(tree: Dictionary) -> bool:
	return TreeSystem.is_tree_burning(tree)

## Dónde se puede caer desde el árbol: un lugar libre, o encima del enemigo.
func can_drop_at(pos: Vector2) -> bool:
	return _tree_system.can_drop_at(pos)

## Sube al árbol y marca dónde va a caer.
func climb_tree(tree: Dictionary, landing: Vector2) -> void:
	_tree_system.climb_tree(tree, landing)

## Cae del árbol a `landing` (si cae sobre el enemigo, queda pegado a él).
## Devuelve si le cayó encima.
func drop_from_tree(landing: Vector2) -> bool:
	return _tree_system.drop_from_tree(landing)

func is_player_in_tree() -> bool:
	return _tree_system.is_player_in_tree()

## Tala el árbol: cae hacia `dir` y queda un tronco tirado. Los tramos que
## caerían encima de alguien no se crean; si es el enemigo, le pega.
## Devuelve {"enemy_hit": bool}. Si el jugador estaba arriba, se cae.
func fell_tree(tree: Dictionary, dir: Vector2) -> Dictionary:
	return _tree_system.fell_tree(tree, dir)

## Prende fuego los árboles que toca el círculo. Devuelve cuántos.
func ignite_trees_in_circle(center: Vector2, radius: float) -> int:
	return _tree_system.ignite_trees_in_circle(center, radius)

## Prende fuego los árboles dentro del cono (Aliento). Devuelve cuántos.
func ignite_trees_in_cone(origin: Vector2, dir: Vector2, cone_range: float, half_angle_deg: float) -> int:
	return _tree_system.ignite_trees_in_cone(origin, dir, cone_range, half_angle_deg)

## Apaga los árboles en llamas que toca el círculo (hielo, agua). Devuelve cuántos.
func extinguish_trees_in_circle(center: Vector2, radius: float) -> int:
	return _tree_system.extinguish_trees_in_circle(center, radius)

## Hay un árbol (que no arde) a `reach` o menos de `pos` (Raíces, charcos de planta).
func is_tree_near(pos: Vector2, reach: float) -> bool:
	return _tree_system.is_tree_near(pos, reach)

## Pararrayos: el primer árbol que cruza el segmento, con la fracción donde lo
## toca: {"tree": Dictionary, "t": float} o {} si no cruza ninguno.
func first_tree_on_segment(from: Vector2, to: Vector2) -> Dictionary:
	return _tree_system.first_tree_on_segment(from, to)

func is_player_in_this_tree(tree: Dictionary) -> bool:
	return _tree_system.is_player_in_this_tree(tree)

## Pasa una ronda: los árboles que arden se consumen y desaparecen.
func tick_trees() -> void:
	_tree_system.tick_trees()

## Lo usa CombatBiomeLayout para construir la malla inicial de un árbol del
## layout, sin conocer el formato interno de TreeSystem.
func build_initial_tree_mesh(mi: MeshInstance3D, obs: Dictionary, pos: Vector2) -> void:
	_tree_system.build_initial_tree_mesh(mi, obs, pos)

## Ancla: muestra el alcance del disparo alrededor del jugador.
func start_anchor_selection(shot_range: float) -> void:
	_show_disc(_attack_disc, player_pos, shot_range)

func push_enemy_to(landing: Vector2) -> void:
	_push_system.push_enemy_to(landing)

func check_traps_along_segment(from: Vector2, to: Vector2, contact_margin: float = 0.0) -> int:
	return _trap_system.check_traps_along_segment(from, to, contact_margin)

# Devuelve {"trap_damage": int, "wet": bool} para un segmento de movimiento forzado.
# Agregar nuevas zonas acá para que cualquier movimiento forzado las active automáticamente.
func trigger_zone_effects_along(from: Vector2, to: Vector2, contact_margin: float = 0.0) -> Dictionary:
	var fx := get_puddle_effects_along(from, to, contact_margin)
	fx["trap_damage"] = check_traps_along_segment(from, to, contact_margin)
	return fx

# ── Puddles (estado y lógica en puddle_system.gd) ──────────────────────────────
func start_puddle_placement(throw_range: float, effect: String = "wet", puddle_radius: float = 1.0) -> void:
	_puddle_system.start_puddle_placement(throw_range, effect, puddle_radius)

func clear_puddle_placement() -> void:
	_puddle_system.clear_puddle_placement()

func place_puddle(pos: Vector2, radius: float, effect: String = "wet", turns: int = 0, damage: int = 0) -> void:
	_puddle_system.place_puddle(pos, radius, effect, turns, damage)

func tick_puddles() -> void:
	_puddle_system.tick_puddles()

func get_puddle_at(pos: Vector2) -> Dictionary:
	return _puddle_system.get_puddle_at(pos)

func remove_puddle(zone: Dictionary) -> void:
	_puddle_system.remove_puddle(zone)

func move_puddle(zone: Dictionary, to: Vector2) -> Dictionary:
	return _puddle_system.move_puddle(zone, to)

## Traslado de charco, paso 2: dónde puede caer (alrededor del charco elegido).
## Reusa el disco genérico de ataque, no es estado propio de los charcos.
func start_puddle_hop_landing(puddle_pos: Vector2, hop_range: float) -> void:
	_show_disc(_attack_disc, puddle_pos, hop_range)

func get_puddle_damage_along(from: Vector2, to: Vector2, contact_margin: float = 0.0) -> Dictionary:
	return _puddle_system.get_puddle_damage_along(from, to, contact_margin)

func is_segment_in_puddle(from: Vector2, to: Vector2) -> bool:
	return _puddle_system.is_segment_in_puddle(from, to)

func get_puddle_effects_along(from: Vector2, to: Vector2, contact_margin: float = 0.0) -> Dictionary:
	return _puddle_system.get_puddle_effects_along(from, to, contact_margin)

## Cambia el efecto de los charcos que toca el círculo (Chispa: grasa → fuego;
## Escarcha: agua → hielo). Devuelve cuántos cambió.
func convert_puddles(center: Vector2, radius: float, from_effects: Array, to_effect: String) -> int:
	return _puddle_system.convert_puddles(center, radius, from_effects, to_effect)

## Charcos de esos efectos que toca el segmento (Descarga se propaga por el agua).
func puddles_on_segment(from: Vector2, to: Vector2, effects: Array) -> Array:
	return _puddle_system.puddles_on_segment(from, to, effects)

# ── Overwatch ─────────────────────────────────────────────────────────────────
func start_overwatch_selection(cone_range: float, half_angle: float) -> void:
	_overwatch_system.start_selection(cone_range, half_angle)

func clear_overwatch_selection() -> void:
	_overwatch_system.clear_selection()

func place_overwatch(origin: Vector2, dir: Vector2, cone_range: float, half_angle: float) -> void:
	_overwatch_system.place(origin, dir, cone_range, half_angle)

func clear_overwatch_zone() -> void:
	_overwatch_system.clear_zone()

func is_segment_in_overwatch_cone(from: Vector2, to: Vector2, origin: Vector2, dir: Vector2, cone_range: float, half_angle_deg: float) -> bool:
	return _overwatch_system.segment_crosses_cone(from, to, origin, dir, cone_range, half_angle_deg)
