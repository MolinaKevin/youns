class_name MapArea
extends CombatMapArea

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
var _construction_impl: CombatMapConstructionAdapter
var _targeting          := CombatTargeting.new()
var _push_system        := CombatPushSystem.new()
var _overwatch_system   := CombatOverwatchSystem.new()
var _renderer           := CombatMapRenderer.new()
var _range_overlay      := CombatRangeOverlay.new()
var _actor_presentation := CombatActorPresentation.new()
var _scene_impl: CombatMapSceneAdapter
var _queries_impl: CombatMapQueries
var _actors_impl: CombatMapActors
var _presentation_impl: CombatMapPresentation
## Las fachadas tipadas reúnen las operaciones de gameplay; los sistemas
## concretos quedan encapsulados en esta escena.
## Alias para que `map.LOG_SEGMENTS` (lo usan los tests) siga andando con el
## dueño real del dato movido a TreeSystem.
const LOG_SEGMENTS := TreeSystem.LOG_SEGMENTS

func _init() -> void:
	player_pos = Vector2(3.0, 27.0)
	enemy_pos = Vector2(27.0, 3.0)
	_queries_impl = CombatMapQueries.new()
	_actors_impl = CombatMapActors.new()
	_presentation_impl = CombatMapPresentation.new()
	state = CombatMapStateAdapter.new(self)
	queries = _queries_impl
	actors = _actors_impl
	presentation = _presentation_impl
	_scene_impl = CombatMapSceneAdapter.new(_input_controller, _actor_presentation)
	scene = _scene_impl
	terrain = CombatMapTerrain.new()
	_construction_impl = CombatMapConstructionAdapter.new(_terrain)
	construction = _construction_impl
	movement = CombatMapMovement.new()
	selection = CombatMapSelectionAdapter.new(self, _targeting, _presentation_impl,
		_trap_system, _grenade_system, _rock_jump_system, _puddle_system,
		_overwatch_system, _push_system, _module_system, _spell_system)
	placement = CombatMapPlacementAdapter.new(_trap_system, _grenade_system, _puddle_system)
	effects = CombatMapEffectsAdapter.new(self, _trap_system, _puddle_system, _spell_system)
	obstacles = CombatMapObstacleAdapter.new(self, _rock_jump_system, _module_system, _tree_system)
	push = CombatMapPushAdapter.new(_push_system)
	add_child(_overlay)
	_input_controller.map = self
	add_child(_input_controller)
	_terrain.configure(WORLD_W, WORLD_H)
	_navigation.configure(_terrain, WORLD_W, WORLD_H)
	_queries_impl.map = self
	_actor_mover.map = self
	_actor_mover.enemy_reached_target.connect(func(): scene.enemy_reached_target.emit())
	_spell_system.map = self
	_targeting.map = self
	_presentation_impl.map = self
	_presentation_impl.overlay = _overlay
	_presentation_impl.renderer = _renderer
	_presentation_impl.range_overlay = _range_overlay
	_presentation_impl.actor_presentation = _actor_presentation
	_presentation_impl.pattern_presentation.overlay = _overlay
	_presentation_impl.pattern_presentation.renderer = _renderer
	_presentation_impl.targeting_presentation.map = self
	_presentation_impl.targeting_presentation.visual_overlay = _overlay
	_presentation_impl.targeting_presentation.renderer = _renderer
	_presentation_impl.targeting_presentation.range_overlay = _range_overlay
	_presentation_impl.overlay_presentation.overlay = _overlay
	_presentation_impl.overlay_presentation.renderer = _renderer
	_presentation_impl.overlay_presentation.range_overlay = _range_overlay
	_presentation_impl.combat_preview_presentation.map = self
	_presentation_impl.combat_preview_presentation.overlay = _overlay
	_presentation_impl.combat_preview_presentation.renderer = _renderer
	_presentation_impl.overwatch_presentation.overlay = _overlay
	_presentation_impl.overwatch_presentation.renderer = _renderer
	_actors_impl.map = self
	_actors_impl.overlay = _overlay
	_actors_impl.renderer = _renderer
	_actors_impl.terrain = terrain
	_actors_impl.mover = _actor_mover
	_actors_impl.trees = _tree_system
	terrain.map = self
	terrain.logic = _terrain
	terrain.navigation_impl = _navigation
	movement.map = self
	_push_system.map = self
	_overwatch_system.map = self
	_range_overlay.terrain = _terrain
	_range_overlay.queries = _queries_impl
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

# ── World bounds ──────────────────────────────────────────────────────────────
const DEFAULT_BIOME: BiomeData = preload("res://data/biomes/pradera.tres")

## Bioma que suministra el layout del combate actual.
var biome: BiomeData

func setup_biome(value: BiomeData) -> void:
	biome = value if value != null else DEFAULT_BIOME
	biome.setup_combat_map(construction)

# ── Elevation ─────────────────────────────────────────────────────────────────
# ── Pathfinding ───────────────────────────────────────────────────────────────
# ── Obstacles ─────────────────────────────────────────────────────────────────
# La geometría inicial llega por `construction`; el estado y sus mutaciones
# durante el combate viven en `terrain`.
# ── Visual ────────────────────────────────────────────────────────────────────
## Los layouts de bioma construyen la visual inicial mediante MapArea; los
## sistemas concretos conservan la implementación de cada tipo de obstáculo.
func build_initial_tree_mesh(mesh_instance: MeshInstance3D, obstacle: Dictionary, grid_position: Vector2) -> void:
	_tree_system.build_initial_tree_mesh(mesh_instance, obstacle, grid_position)


func build_initial_rock_mesh(mesh_instance: MeshInstance3D, obstacle: Dictionary, grid_position: Vector2, material: StandardMaterial3D) -> void:
	_module_system.build_initial_rock_mesh(mesh_instance, obstacle, grid_position, material)


## Alturas de los resaltados sobre el suelo: la sombra está en 0.02.
## Un área tiene que cubrir este tramo del radio de la huella para afectarla.
## Las colisiones físicas conservan el radio completo.
## Cuánto más allá de la huella un clic sigue contando como "sobre el personaje".

# ── Movement animation ────────────────────────────────────────────────────────

# ── Init ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_setup_ground()
	_overlay.setup()

	biome.build_combat_map(self, construction)
	_scene_impl.setup_actors()

func _setup_ground() -> void:
	add_child(_renderer.make_ground(WORLD_W, WORLD_H))

func _process(delta: float) -> void:
	_warm_grid_caches()
	_actor_mover.update(delta)

## Llena de a poco los cachés de altura y de obstáculos (con las huellas de
## ambos personajes) para que el primer movimiento no tenga un tirón.
func _warm_grid_caches() -> void:
	terrain.mutation.warm_caches(actors.player_radius(), actors.enemy_radius())

## Dibuja las casillas dadas apoyadas sobre el terreno (cada una a su altura).
## Arreglos pre-dimensionados: con alcances grandes son decenas de miles de casillas.
