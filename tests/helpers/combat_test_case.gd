extends GutTest

const MockEffects := preload("res://tests/helpers/mock_combat_effects.gd")
const MockNavigation := preload("res://tests/helpers/mock_combat_navigation.gd")
const TestData := preload("res://tests/helpers/combat_test_data_fixture.gd")
const MockPushScript := preload("res://tests/helpers/mock_combat_push.gd")
const MockSelectionScript := preload("res://tests/helpers/mock_combat_selection.gd")
const MockObstaclesScript := preload("res://tests/helpers/mock_combat_obstacles.gd")

## Base común para pruebas de combate que necesitan un tablero controlado.
## Mantiene el doble separado de los casos, para que las pruebas se agrupen
## por comportamiento y no por el tamaño del mock.

## Contenedor de estado para dobles de puertos; no implementa la API heredada
## de MapArea.
class MockCombatMap extends CombatMapArea:
	class MockQueries extends CombatMapQueries:
		var owner: MockCombatMap

		class MockLineOfSight extends CombatMapLineOfSightPort:
			var owner: MockQueries
			func has_line_of_sight(from: Vector2, to: Vector2) -> bool: return owner.has_line_of_sight(from, to)
			func line_of_sight_clear(from: Vector2, to: Vector2, block_rocks: bool, block_bridges: bool, from_elevation: int, to_elevation: int) -> bool:
				return owner.line_of_sight_clear(from, to, block_rocks, block_bridges, from_elevation, to_elevation)

		class MockActorsQueries extends CombatMapActorQueriesPort:
			var owner: MockQueries
			func movement_distance(from: Vector2, to: Vector2) -> float: return owner.movement_distance(from, to)
			func actors_gap() -> float: return owner.actors_gap()
			func is_enemy_in_attack_range(value: float) -> bool: return owner.is_enemy_in_attack_range(value)
			func is_enemy_in_melee_range() -> bool: return owner.is_enemy_in_melee_range()
			func is_player_in_melee_range() -> bool: return owner.is_player_in_melee_range()
			func player_area_contact_radius() -> float: return owner.player_area_contact_radius()
			func enemy_area_contact_radius() -> float: return owner.enemy_area_contact_radius()

		class MockAreaQueries extends CombatMapAreaQueriesPort:
			var owner: MockQueries
			func is_enemy_in_zones(value: Array) -> bool: return owner.is_enemy_in_zones(value)
			func is_player_in_zones(value: Array) -> bool: return owner.is_player_in_zones(value)
			func segment_hits_enemy(from: Vector2, to: Vector2) -> bool: return owner.segment_hits_enemy(from, to)
			func is_enemy_in_cone(origin: Vector2, direction: Vector2, cone_range: float, half_angle_deg: float) -> bool: return owner.is_enemy_in_cone(origin, direction, cone_range, half_angle_deg)
			func is_enemy_in_area_circle(center: Vector2, radius: float) -> bool: return owner.is_enemy_in_area_circle(center, radius)
			func is_player_in_area_circle(center: Vector2, radius: float) -> bool: return owner.is_player_in_area_circle(center, radius)
			func is_enemy_in_circle(center: Vector2, radius: float) -> bool: return owner.is_enemy_in_circle(center, radius)
			func is_player_in_circle(center: Vector2, radius: float) -> bool: return owner.is_player_in_circle(center, radius)

		func _init() -> void:
			var los := MockLineOfSight.new(); los.owner = self; line_of_sight = los
			var actors_double := MockActorsQueries.new(); actors_double.owner = self; actors = actors_double
			var areas_double := MockAreaQueries.new(); areas_double.owner = self; areas = areas_double

		func has_line_of_sight(_from: Vector2, _to: Vector2) -> bool:
			return owner.los_result

		func movement_distance(from: Vector2, to: Vector2) -> float:
			return from.distance_to(to)

		func is_enemy_in_area_circle(center: Vector2, radius: float) -> bool:
			return center.distance_to(owner.enemy_pos) <= radius

		func is_enemy_in_cone(origin: Vector2, direction: Vector2, cone_range: float, half_angle_deg: float) -> bool:
			var to_enemy := owner.enemy_pos - origin
			return to_enemy.length() <= cone_range and (to_enemy.length() < 0.001 or absf(direction.normalized().angle_to(to_enemy.normalized())) <= deg_to_rad(half_angle_deg))

		func is_enemy_in_attack_range(_range: float) -> bool: return true
		func actors_gap() -> float: return owner.player_pos.distance_to(owner.enemy_pos) - 1.3
		func player_area_contact_radius() -> float: return 0.0
		func enemy_area_contact_radius() -> float: return 0.0
		func segment_hits_enemy(from: Vector2, to: Vector2) -> bool:
			return owner.enemy_pos.distance_to(Geometry2D.get_closest_point_to_segment(owner.enemy_pos, from, to)) <= 0.4
		func is_enemy_in_zones(zones: Array) -> bool:
			for zone in zones:
				if owner.enemy_pos.distance_to(zone["pos"]) <= float(zone["radius"]):
					return true
			return false
		func is_player_in_zones(zones: Array) -> bool:
			for zone in zones:
				if owner.player_pos.distance_to(zone["pos"]) <= float(zone["radius"]):
					return true
			return false

	class MockActors extends CombatMapActors:
		var owner: MockCombatMap
		func play_player_animation(_animation: String) -> void: owner.player_anim_finished.emit.call_deferred()
		func play_enemy_animation(_animation: String) -> void: owner.enemy_anim_finished.emit.call_deferred()

	class MockPresentation extends CombatMapPresentation:
		var owner: MockCombatMap
		func _init() -> void:
			patterns = CombatMapPatternPort.new()
			targeting = CombatMapTargetingPresentationPort.new()
			targeting.overlay.ranges = CombatMapTargetingRangeAdapter.new(self)
			targeting.overlay.path = CombatMapTargetingPathAdapter.new(self)
			targeting.overlay.actors = CombatMapTargetingActorHighlightsAdapter.new(self)
			overlay_port = CombatMapOverlayPort.new()
			combat_preview = CombatMapCombatPreviewPort.new()
			overwatch = CombatMapOverwatchPort.new()
		func show_card_pattern(_pattern: CardPattern, _origin: Vector2, _direction: Vector2, _primary: float) -> void: pass
		func clear_card_pattern() -> void: pass
		func show_path_preview() -> void: pass
		func clear_path_preview() -> void: pass
		func show_enemy_highlight() -> void: pass
		func clear_enemy_highlight() -> void: pass
		func show_self_highlight() -> void: pass
		func clear_self_highlight() -> void: pass
		func is_click_on_player(_pos: Vector2) -> bool: return true
		func is_enemy_in_card_pattern(_pattern: CardPattern, _origin: Vector2, _direction: Vector2, _primary: float) -> bool: return true

	class MockPlacement extends CombatMapPlacementPort:
		var owner: MockCombatMap
		func _init() -> void:
			traps = CombatMapTrapPlacementAdapter.new(self)
			grenades = CombatMapGrenadePlacementAdapter.new(self)
			puddles = CombatMapPuddlePlacementAdapter.new(self)
		func start_trap_placement(_reach: float, _radius: float = 1.0, _preview_los: bool = true) -> void: pass
		func clear_trap_placement() -> void: pass
		func place_trap(pos: Vector2, radius: float, damage: int, card_name: String) -> void:
			owner.place_trap_calls.append({"pos": pos, "radius": radius, "damage": damage, "name": card_name})
		func grenade_landing(_from: Vector2, target: Vector2, _bounce: float) -> Vector2: return target
		func show_grenade_preview(_landing: Vector2, _radius: float) -> void: pass
		func clear_grenade_preview() -> void: pass
		func is_enemy_in_explosion(_center: Vector2, _radius: float) -> bool: return true
		func start_puddle_placement(_reach: float, _effect: String, _radius: float) -> void: pass
		func clear_puddle_placement() -> void: pass
		func place_puddle(pos: Vector2, radius: float, effect: String = "wet", turns: int = 0, damage: int = 0) -> void:
			owner.place_puddle_calls.append({"pos": pos, "radius": radius, "effect": effect, "turns": turns, "damage": damage})

	var los_result := true
	var selection_double
	var puddle_effects_result: Dictionary = {}
	var puddle_damage_result: Dictionary = {}
	var overwatch_cone_hit := false
	var move_enemy_toward_calls := 0
	var start_move_selection_calls := 0
	var clear_overwatch_zone_calls := 0
	var place_puddle_calls: Array = []
	var place_trap_calls: Array = []
	var place_delayed_zone_calls: Array = []
	var push_enemy_to_calls: Array = []
	var build_modules_calls: Array = []
	var break_modules_calls: Array = []
	var blink_calls: Array = []
	signal player_anim_finished
	signal enemy_reached_target
	signal enemy_anim_finished

	func _init() -> void:
		player_pos = Vector2.ZERO
		enemy_pos = Vector2(10.0, 0.0)
		queries = MockQueries.new()
		queries.owner = self
		actors = MockActors.new()
		actors.owner = self
		presentation = MockPresentation.new()
		presentation.owner = self
		selection_double = MockSelectionScript.new()
		selection_double.owner = self
		selection_double.targeting.owner = self
		selection_double.actions.owner = self
		selection = selection_double
		var placement_double := MockPlacement.new(); placement_double.owner = self; placement = placement_double
		var effects_double := MockEffects.new(); effects_double.owner = self; effects = effects_double
		var obstacles_double := MockObstaclesScript.new(); obstacles_double.owner = self; obstacles = obstacles_double
		var push_double := MockPushScript.new(); push_double.owner = self; push = push_double
		terrain = MockNavigation.Terrain.new()
		terrain.owner = self
		movement = MockNavigation.Movement.new()
		movement.owner = self
		state = CombatMapStateAdapter.new(self)

var _map: MockCombatMap
var _enemy_board: MockEnemyBoard


func _make_ai(p_state: CombatState) -> CombatEnemyAI:
	var ai := CombatEnemyAI.new()
	ai.setup_with_board(p_state, _enemy_board, null, Callable(), Callable(), Callable())
	return ai


func _dmg_enemy_callable(state: CombatState) -> Callable:
	return func(amount: int, _skip_anim: bool = false, damage_type: String = CombatState.FISICO) -> void:
		state.damage_enemy(amount, damage_type)


func _dmg_player_callable(state: CombatState) -> Callable:
	return func(amount: int, _skip_anim: bool = false, damage_type: String = CombatState.FISICO) -> void:
		state.damage_player(amount, damage_type)


func _check_end_callable(state: CombatState) -> Callable:
	return func() -> bool:
		return state.enemy_hp <= 0 or state.player_hp <= 0


func _make_ai_full(state: CombatState, strategy: AiStrategy = null) -> CombatEnemyAI:
	var ai := CombatEnemyAI.new()
	ai.setup_with_board(state, _enemy_board, strategy, _dmg_enemy_callable(state), _dmg_player_callable(state), _check_end_callable(state))
	return ai


func _make_card(type: String, block: int = 0, damage: int = 0) -> CardActionLine:
	return TestData.card(type, block, damage)


func _make_player_actions(state: CombatState) -> CombatPlayerActions:
	var actions := CombatPlayerActions.new()
	actions.setup(state, _map, Callable(), Callable(), Callable())
	return actions


func _make_full_player_actions(state: CombatState) -> CombatPlayerActions:
	var actions := CombatPlayerActions.new()
	actions.setup(state, _map, _dmg_enemy_callable(state), _dmg_player_callable(state), _check_end_callable(state))
	return actions


func _make_monster_action(type: String, value: int = 0, range_mod: int = 0) -> MonsterCardAction:
	return TestData.monster_action(type, value, range_mod)


func _make_monster_card(initiative: int, actions: Array) -> MonsterCard:
	return TestData.monster_card(initiative, actions)


func _make_monster_deck(cards: Array, base_move := 63, base_attack := 6, base_range := 0) -> MonsterDeck:
	return TestData.monster_deck(cards, base_move, base_attack, base_range)


func _make_card_ai(state: CombatState, deck: MonsterDeck) -> CombatEnemyAI:
	var ai := _make_ai_full(state)
	ai.set_monster_deck(deck)
	ai.action_delay = 0.0
	return ai


func _make_condition(type: String, check_range: float = 12.0) -> AiCondition:
	return TestData.condition(type, check_range)


func _make_action(type: String, score: float, conditions: Array,
		score_multiplier_low_hp: float = 1.0, block_amount: int = 0) -> AiAction:
	return TestData.action(type, score, conditions, score_multiplier_low_hp, block_amount)


func _make_phase(phase_name: String, actions: Array) -> AiPhase:
	return TestData.phase(phase_name, actions)


func _make_transition(from: String, to: String, conditions: Array) -> AiPhaseTransition:
	return TestData.phase_transition(from, to, conditions)


func _make_phase_strategy(initial: String, phases: Array, transitions: Array = []) -> AiStrategy:
	return TestData.phase_strategy(initial, phases, transitions)

func before_each() -> void:
	_map = MockCombatMap.new()
	add_child(_map)
	_enemy_board = MockEnemyBoard.new()
	_enemy_board.map = _map

func after_each() -> void:
	_map.free()
	_map = null
	_enemy_board = null
