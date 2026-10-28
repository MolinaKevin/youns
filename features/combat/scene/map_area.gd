class_name MapArea
extends CombatMapArea

const CombatObstacle := preload("res://features/combat/scene/combat_obstacle.gd")

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
var _actor_mover        := CombatActorMover.new()
var _spell_system       := CombatSpellSystem.new()
var _terrain            := CombatTerrain.new()
var _targeting          := CombatTargeting.new()
var _push_system        := CombatPushSystem.new()
var _overwatch_system   := CombatOverwatchSystem.new()
var _renderer           := CombatMapRenderer.new()
var _range_overlay      := CombatRangeOverlay.new()
var _actor_presentation := CombatActorPresentation.new()
## API que reúne los modos de colocación y sus previews de hover. El gameplay
## nuevo debe depender de esta fachada, `queries`, `movement`, `presentation`
## o `actors`, no de métodos sueltos de MapArea.
## Alias para que `map.LOG_SEGMENTS` (lo usan los tests) siga andando con el
## dueño real del dato movido a TreeSystem.
const LOG_SEGMENTS := TreeSystem.LOG_SEGMENTS
## Las plantas consultan estos valores a través de MapArea. TreeSystem es el
## dueño de la regla, pero esta fachada evita que PuddleSystem dependa de la
## estructura interna de MapArea.
const TREE_VINE_RADIUS_MULT := TreeSystem.TREE_VINE_RADIUS_MULT
const TREE_VINE_REACH := TreeSystem.TREE_VINE_REACH

func _init() -> void:
	player_pos = Vector2(3.0, 27.0)
	enemy_pos = Vector2(27.0, 3.0)
	queries = CombatMapQueries.new()
	actors = CombatMapActors.new()
	presentation = CombatMapPresentation.new()
	terrain = CombatMapTerrain.new()
	movement = CombatMapMovement.new()
	interactions = CombatMapInteractions.new()
	add_child(_overlay)
	_input_controller.map = self
	_input_controller.position_selected.connect(func(pos): position_selected.emit(pos))
	add_child(_input_controller)
	_terrain.configure(WORLD_W, WORLD_H)
	_navigation.configure(_terrain, WORLD_W, WORLD_H)
	queries.map = self
	_actor_mover.map = self
	_actor_mover.enemy_reached_target.connect(func(): enemy_reached_target.emit())
	_spell_system.map = self
	_targeting.map = self
	presentation.map = self
	presentation.overlay = _overlay
	presentation.renderer = _renderer
	presentation.range_overlay = _range_overlay
	presentation.actor_presentation = _actor_presentation
	actors.map = self
	actors.overlay = _overlay
	actors.renderer = _renderer
	actors.terrain = terrain
	actors.mover = _actor_mover
	actors.trees = _tree_system
	terrain.map = self
	terrain.logic = _terrain
	terrain.navigation = _navigation
	movement.map = self
	interactions.map = self
	interactions.trap_system = _trap_system
	interactions.grenade_system = _grenade_system
	interactions.rock_jump_system = _rock_jump_system
	interactions.puddle_system = _puddle_system
	interactions.overwatch_system = _overwatch_system
	interactions.push_system = _push_system
	interactions.module_system = _module_system
	interactions.spell_system = _spell_system
	interactions.tree_system = _tree_system
	interactions.targeting = _targeting
	interactions.presentation = presentation
	_push_system.map = self
	_overwatch_system.map = self
	_range_overlay.terrain = _terrain
	_range_overlay.queries = queries
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
const DEFAULT_BIOME: BiomeData = preload("res://data/biomes/pradera.tres")

## Bioma que suministra el layout del combate actual.
var biome: BiomeData

func setup_biome(value: BiomeData) -> void:
	biome = value if value != null else DEFAULT_BIOME
	biome.setup_combat_map(self)

# ── Shared combat state ───────────────────────────────────────────────────────
var _enemy_move_pending:
	get: return _actor_mover.enemy_move_pending
	set(value): _actor_mover.enemy_move_pending = value
## Reenvío a PuddleSystem (compat con combat_player_actions.gd/combat_enemy_ai.gd/tests).

# ── Elevation ─────────────────────────────────────────────────────────────────
# ── Pathfinding ───────────────────────────────────────────────────────────────
# ── Obstacles ─────────────────────────────────────────────────────────────────
# type CombatObstacle.SOLID  → bloquea movimiento Y línea de visión
# type CombatObstacle.ROCK   → bloquea movimiento, LOS pasa a través (piedra pequeña)
# type CombatObstacle.BRIDGE → movimiento permitido por debajo, LOS bloqueada (puente)
# "module": true → es un módulo: se puede romper, golpear y saltar desde él
#                  (las piedras chicas; las cartas crean más, ver build_modules)
## Lo provee el CombatBiomeLayout; CombatTerrain conserva e interpreta esa
## geometría durante el combate. Devuelve el array real (no una copia): lo
## usan los tests para armar tableros a mano y CombatBiomeLayout para leerlo
## una vez al construir los visuales. El código de juego que agrega, saca o
## mueve obstáculos durante el combate no debe usar esto — tiene que pasar
## por `terrain.add_obstacle()`/`terrain.remove_obstacle()` (o mutar en el
## lugar, como slide_module), que son los que saben invalidar los cachés de
## CombatTerrain.
var solid_obstacles: Array[Dictionary]:
	get: return _terrain.obstacles

## ── API de construcción de biomas ────────────────────────────────────────────
## CombatBiomeLayout usa estos métodos en vez de depender del formato interno
## de `solid_obstacles`. Los elementos agregados acá son el estado inicial;
## durante el combate los sistemas pueden mutarlos o agregar módulos propios.
func clear_biome_obstacles() -> void:
	_terrain.clear()

func add_solid(pos: Vector2, radius: float) -> void:
	_terrain.add({"pos": pos, "radius": radius, "type": CombatObstacle.SOLID})

func add_solid_box(pos: Vector2, size: Vector2) -> void:
	_terrain.add({"pos": pos, "box": size, "type": CombatObstacle.SOLID})

func add_rock(pos: Vector2, radius: float, module: bool = true) -> void:
	_terrain.add({"pos": pos, "radius": radius, "type": CombatObstacle.ROCK, "module": module})

func add_bridge(pos: Vector2, size: Vector2) -> void:
	_terrain.add({"pos": pos, "box": size, "type": CombatObstacle.BRIDGE})

func add_tree(pos: Vector2, radius: float = 0.6) -> void:
	_terrain.add({"pos": pos, "radius": radius, "type": CombatObstacle.TREE})

func add_platform(pos: Vector2, size: Vector2, ramps: Array[Dictionary] = []) -> void:
	_terrain.add({"pos": pos, "box": size, "type": CombatObstacle.PLATFORM, "ramps": ramps.duplicate(true)})

const RAMP_DEPTH      := 1.5

# ── Visual ────────────────────────────────────────────────────────────────────
## Alturas de los resaltados sobre el suelo: la sombra está en 0.02.
## Un área tiene que cubrir este tramo del radio de la huella para afectarla.
## Las colisiones físicas conservan el radio completo.
## Cuánto más allá de la huella un clic sigue contando como "sobre el personaje".

# ── Movement animation ────────────────────────────────────────────────────────
const ACTOR_MOVE_SPEED  := 12.0

# ── Init ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_setup_ground()
	_overlay.setup()

	biome.build_combat_map(self)
	_setup_actors()

func _setup_ground() -> void:
	add_child(_renderer.make_ground(WORLD_W, WORLD_H))

func make_mat(color: Color) -> StandardMaterial3D:
	return _overlay.make_material(color)

func make_disc(color: Color) -> MeshInstance3D:
	return _overlay.make_disc(color)

func show_disc(mi: MeshInstance3D, center: Vector2, radius: float) -> void:
	_renderer.show_disc(mi, center, radius)

func show_simple_disc(mi: MeshInstance3D, center: Vector2, radius: float) -> void:
	_renderer.show_simple_disc(mi, center, radius)

func build_tile_disc(mi: MeshInstance3D, center: Vector2, radius: float, inner_radius: float, y: float, exclusions: Array = []) -> void:
	_renderer.build_tile_disc(mi, center, radius, inner_radius, y, exclusions)

## Pinta las casillas de la huella de un personaje (las mismas de su sombra).
func show_footprint(mi: MeshInstance3D, center: Vector2, radius: float, y := HIGHLIGHT_Y) -> void:
	_renderer.show_footprint(mi, center, radius, y)


func _setup_actors() -> void:
	_actor_presentation.setup_actors()

func setup_player(data: YounData) -> void:
	_actor_presentation.setup_player(data)

func play_player_anim(anim_key: String) -> void:
	actors.play_player_animation(anim_key)

func setup_enemy_youn(data: YounData) -> void:
	_actor_presentation.setup_enemy(data)

func play_enemy_anim(anim_key: String) -> void:
	actors.play_enemy_animation(anim_key)

func update_actor_positions() -> void:
	actors.sync_targets()

func _process(delta: float) -> void:
	_warm_grid_caches()
	_actor_mover.update(delta)

func lock_hover_at_last_click() -> void:
	_input_controller.lock_hover_at_last_click()

func unlock_hover() -> void:
	_input_controller.unlock_hover()

func is_hover_locked() -> bool:
	return _input_controller.is_hover_locked()

func set_status_texts(player_text: String, enemy_text: String) -> void:
	_actor_presentation.set_status_texts(player_text, enemy_text)

func place_status_labels() -> void:
	_actor_presentation.place_status_labels()

func update_hover_at(pos: Vector2) -> void:
	_targeting.update_hover(pos)

func clear_hover() -> void:
	_targeting.clear_hover()

func show_single_cell(mi: MeshInstance3D, world_pos: Vector2) -> void:
	var center := _renderer.visual_cell_center(world_pos)
	_renderer.show_single_cell(mi, center, _terrain.height_at(center))

# ── Helpers ───────────────────────────────────────────────────────────────────
func movement_distance(a: Vector2, b: Vector2) -> float:
	return a.distance_to(b)

# ── Terrain (fachada de CombatTerrain) ─────────────────────────────────────────
func elevation_at(pos: Vector2) -> int:
	return _terrain.elevation_at(pos)

# ── Move ──────────────────────────────────────────────────────────────────────
func start_move_selection(move_range: float) -> void:
	_targeting.start_move_selection(move_range)


func tile_in_obstacle(pos: Vector2, elevation: int = 0) -> bool:
	return _terrain.tile_in_obstacle(pos, elevation)

func apply_two_surface_mesh(mi: MeshInstance3D,
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

func render_path_preview() -> void:
	_range_overlay.render_path_preview(_overlay.path_highlight, terrain.planned_path())

func clear_path_preview() -> void:
	_targeting.clear_path_preview()

func try_move_player_to(pos: Vector2) -> bool:
	return movement.try_move_player_to(pos)

func get_path_cost() -> float:
	return movement.path_cost()

## Prepara el movimiento del jugador hacia pos dentro de la selección actual.
## Devuelve "" si se puede (y deja el camino listo para show_path_preview),
## o el motivo: "range", "blocked" o "no_path".
func plan_player_move(pos: Vector2) -> String:
	return movement.plan_player_move(pos)

## Llena de a poco los cachés de altura y de obstáculos (con las huellas de
## ambos personajes) para que el primer movimiento no tenga un tirón.
func _warm_grid_caches() -> void:
	terrain.warm_caches(actors.player_radius(), actors.enemy_radius())

## Dibuja las casillas dadas apoyadas sobre el terreno (cada una a su altura).
## Arreglos pre-dimensionados: con alcances grandes son decenas de miles de casillas.
func build_cells_on_terrain(mi: MeshInstance3D, cells: Array) -> void:
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


func build_line_pattern(mi: MeshInstance3D, origin: Vector2, direction: Vector2, length: float, width: float, start_offset: float) -> void:
	_renderer.build_line_pattern(mi, origin, direction, length, width, start_offset,
		make_mat(Color(0.95, 0.65, 0.15, 0.35)))

## Distancia entre los bordes de las huellas del jugador y del enemigo.
func actors_gap() -> float:
	return queries.actors_gap()

## El alcance se mide entre los bordes de las huellas: con huellas circulares
## los centros nunca quedan a menos de la suma de los radios. Media casilla de
## tolerancia porque las posiciones caen en centros de casilla.
func is_enemy_in_attack_range(attack_range: float) -> bool:
	return queries.is_enemy_in_attack_range(attack_range)

func is_enemy_in_melee_range() -> bool:
	return queries.is_enemy_in_melee_range()

func is_player_in_melee_range() -> bool:
	return queries.is_player_in_melee_range()

# ── LOS ───────────────────────────────────────────────────────────────────────
# LOS para ataques de rango: rocas transparentes, puentes opacos.
func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	return queries.has_line_of_sight(from, to)

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
