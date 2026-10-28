extends GutTest

## Base común para pruebas de combate que necesitan un tablero controlado.
## Mantiene el doble separado de los casos, para que las pruebas se agrupen
## por comportamiento y no por el tamaño del mock.

## Contenedor de estado para dobles de puertos; no implementa la API heredada
## de MapArea.
class MockCombatMap extends CombatMapArea:
	class MockQueries extends CombatMapQueries:
		var owner: MockCombatMap

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
		func show_card_pattern(_pattern: CardPattern, _origin: Vector2, _direction: Vector2, _primary: float) -> void: pass
		func clear_card_pattern() -> void: pass
		func show_path_preview() -> void: pass
		func clear_path_preview() -> void: pass
		func show_enemy_highlight() -> void: pass
		func clear_enemy_highlight() -> void: pass
		func show_self_highlight() -> void: pass
		func clear_self_highlight() -> void: pass

	class MockInteractions extends CombatMapInteractions:
		var owner: MockCombatMap
		func puddle_effects_along(from: Vector2, to: Vector2, contact_margin := 0.0) -> Dictionary:
			return owner.puddle_effects_result
		func zone_effects_along(from: Vector2, to: Vector2, contact_margin := 0.0) -> Dictionary:
			return owner.puddle_effects_result
		func puddle_damage_along(from: Vector2, to: Vector2, contact_margin := 0.0) -> Dictionary:
			return owner.puddle_damage_result
		func is_tree_near(pos: Vector2, reach: float) -> bool:
			return false
		func start_move_selection(_reach: float) -> void: owner.start_move_selection_calls += 1
		func clear_move_selection() -> void: pass
		func start_attack_selection(_reach: float) -> void: pass
		func clear_attack_selection() -> void: pass
		func start_trap_placement(_reach: float, _radius := 1.0, _preview_los := true) -> void: pass
		func clear_trap_placement() -> void: pass
		func place_trap(pos: Vector2, radius: float, damage: int, card_name: String) -> void:
			owner.place_trap_calls.append({"pos": pos, "radius": radius, "damage": damage, "name": card_name})
		func trigger_traps(_pos: Vector2, _contact_margin := 0.0) -> int: return 0
		func trigger_traps_along(from: Vector2, to: Vector2, contact_margin := 0.0) -> int:
			return 0
		func grenade_landing(_from: Vector2, target: Vector2, _bounce: float) -> Vector2: return target
		func show_grenade_preview(_landing: Vector2, _radius: float) -> void: pass
		func clear_grenade_preview() -> void: pass
		func is_enemy_in_explosion(_center: Vector2, _radius: float) -> bool: return true
		func start_rock_jump_selection(_reach: float) -> void: pass
		func clear_rock_jump_selection() -> void: pass
		func rocks_in_range(_origin: Vector2, _reach: float) -> Array[Dictionary]: return [{"pos": Vector2(5.0, 0.0)}]
		func rock_near(pos: Vector2) -> Dictionary: return {"pos": pos}
		func start_jump_landing_selection(_rock_pos: Vector2, _reach: float) -> void: pass
		func can_jump_land_at(_pos: Vector2) -> bool: return true
		func land_player_from_jump(pos: Vector2) -> void: owner.player_pos = pos
		func is_enemy_near(pos: Vector2, radius: float) -> bool: return pos.distance_to(owner.enemy_pos) <= radius
		func start_puddle_placement(_reach: float, _effect: String, _radius: float) -> void: pass
		func clear_puddle_placement() -> void: pass
		func place_puddle(pos: Vector2, radius: float, effect: String = "wet", turns: int = 0, damage: int = 0) -> void:
			owner.place_puddle_calls.append({"pos": pos, "radius": radius, "effect": effect, "turns": turns, "damage": damage})
		func tick_puddles() -> void: pass
		func puddle_at(_pos: Vector2) -> Dictionary: return {}
		func start_puddle_hop_landing(_pos: Vector2, _reach: float) -> void: pass
		func start_overwatch_selection(_reach: float, _angle: float) -> void: pass
		func clear_overwatch_selection() -> void: pass
		func place_overwatch(_origin: Vector2, _direction: Vector2, _reach: float, _angle: float) -> void: pass
		func clear_overwatch_zone() -> void: owner.clear_overwatch_zone_calls += 1
		func segment_is_in_overwatch_cone(from: Vector2, to: Vector2, origin: Vector2, dir: Vector2, cone_range: float, half_angle_deg: float) -> bool:
			return owner.overwatch_cone_hit
		func start_push_enemy_selection(_reach: float) -> void: pass
		func start_anchor_selection(_reach: float, _origin: Vector2) -> void: pass
		func start_push_cone(_reach: float) -> void: pass
		func clear_push_selection() -> void: pass
		func is_pos_in_push_cone(_pos: Vector2, _reach: float) -> bool: return true
		func calculate_push_landing(target: Vector2, _reach: float) -> Vector2: return target
		func calculate_drag_landing(target: Vector2, _reach: float) -> Vector2: return target
		func push_enemy_to(pos: Vector2) -> void:
			owner.push_enemy_to_calls.append(pos)
			owner.enemy_pos = pos
			owner.enemy_reached_target.emit.call_deferred()
		func start_module_selection(_reach: float) -> void: pass
		func clear_module_selection() -> void: pass
		func start_collapse_selection(_reach: float) -> void: pass
		func start_module_throw_target(_reach: float) -> void: pass
		func start_module_push_cone(_pos: Vector2, _reach: float, _angle: float) -> void: pass
		func is_pos_in_module_cone(_origin: Vector2, _pos: Vector2, _reach: float, _angle: float) -> bool: return true
		func module_at(_pos: Vector2) -> Dictionary: return {}
		func obstacle_gap(_obstacle: Dictionary) -> float: return 0.0
		func break_modules(obstacle: Dictionary, count: int) -> int:
			owner.break_modules_calls.append({"obs": obstacle, "count": count})
			return count
		func build_modules(pos: Vector2, count: int) -> int:
			owner.build_modules_calls.append({"pos": pos, "count": count})
			return count
		func slide_module(_obstacle: Dictionary, _direction: Vector2, _distance: float) -> Dictionary: return {"hit": "", "tree": {}}
		func throw_module(_obstacle: Dictionary, _target: Vector2) -> Dictionary: return {"enemy": false, "player": false}
		func collapse_modules_on_enemy() -> int: return 0
		func start_spell_selection(_reach: float) -> void: pass
		func clear_spell_selection() -> void: pass
		func place_delayed_zone(pos: Vector2, radius: float, damage: int, _name: String, rounds: int = 1, effect: String = "", duration: int = 0) -> void:
			owner.place_delayed_zone_calls.append({"pos": pos, "radius": radius, "damage": damage, "delay": rounds, "effect": effect, "duration": duration})
		func blink_player_to(pos: Vector2) -> void: owner.blink_calls.append(pos)
		func tree_at(_pos: Vector2) -> Dictionary: return {}
		func can_drop_at(_pos: Vector2) -> bool: return true
		func is_tree_burning(_tree: Dictionary) -> bool: return false
		func tick_trees() -> void: pass
		func is_click_on_enemy(_pos: Vector2) -> bool: return true
		func is_click_on_player(_pos: Vector2) -> bool: return true
		func is_enemy_in_card_pattern(_pattern: CardPattern, _origin: Vector2, _direction: Vector2, _primary: float) -> bool: return true

	class MockTerrain extends CombatMapTerrainPort:
		var owner: MockCombatMap
		func can_blink_to(_pos: Vector2) -> bool: return true

	class MockMovement extends CombatMapMovementPort:
		var owner: MockCombatMap
		func move_enemy_toward(_target: Vector2, _move_range: float) -> bool:
			owner.move_enemy_toward_calls += 1
			return true
		func plan_player_move(_pos: Vector2) -> String: return ""
		func path_cost() -> float: return 0.0
		func try_move_player_to(pos: Vector2) -> bool:
			owner.player_pos = pos
			return true

	var los_result := true
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
		interactions = MockInteractions.new()
		interactions.owner = self
		terrain = MockTerrain.new()
		terrain.owner = self
		movement = MockMovement.new()
		movement.owner = self

## Doble pequeño del tablero que usa la IA enemiga. A diferencia de MockMapArea
## no hereda la escena: sólo adapta las señales que las pruebas necesitan.
class MockEnemyBoard extends CombatEnemyBoardPort:
	var map: MockCombatMap

	func player_position() -> Vector2: return map.player_pos
	func enemy_position() -> Vector2: return map.enemy_pos
	func world_center() -> Vector2: return Vector2(map.WORLD_W * 0.5, map.WORLD_H * 0.5)
	func clamp_to_world(pos: Vector2) -> Vector2:
		return Vector2(clampf(pos.x, 0.0, map.WORLD_W), clampf(pos.y, 0.0, map.WORLD_H))
	func has_line_of_sight(from: Vector2, to: Vector2) -> bool: return map.queries.has_line_of_sight(from, to)
	func movement_distance(from: Vector2, to: Vector2) -> float: return map.queries.movement_distance(from, to)
	func actors_gap() -> float: return map.queries.actors_gap()
	func enemy_contact_radius() -> float: return map.queries.enemy_area_contact_radius()
	func trigger_enemy_traps() -> int: return map.interactions.trigger_traps(map.enemy_pos)
	func move_enemy_toward(target: Vector2, move_range: float) -> bool: return map.movement.move_enemy_toward(target, move_range)
	func puddle_effects_along(from: Vector2, to: Vector2, contact_margin: float) -> Dictionary:
		return map.interactions.puddle_effects_along(from, to, contact_margin)
	func puddle_damage_along(from: Vector2, to: Vector2, contact_margin: float) -> Dictionary:
		return map.interactions.puddle_damage_along(from, to, contact_margin)
	func crosses_player_overwatch(from: Vector2, to: Vector2, origin: Vector2, direction: Vector2, cone_range: float, half_angle: float) -> bool:
		return map.interactions.segment_is_in_overwatch_cone(from, to, origin, direction, cone_range, half_angle)
	func clear_player_overwatch() -> void: map.interactions.clear_overwatch_zone()


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
	var card := CardActionLine.new()
	card.card_type = type
	card.block_amount = block
	card.damage = damage
	card.name = "TestCard"
	return card


func _make_player_actions(state: CombatState) -> CombatPlayerActions:
	var actions := CombatPlayerActions.new()
	actions.setup(state, _map, Callable(), Callable(), Callable())
	return actions


func _make_full_player_actions(state: CombatState) -> CombatPlayerActions:
	var actions := CombatPlayerActions.new()
	actions.setup(state, _map, _dmg_enemy_callable(state), _dmg_player_callable(state), _check_end_callable(state))
	return actions


func _make_monster_action(type: String, value: int = 0, range_mod: int = 0) -> MonsterCardAction:
	var action := MonsterCardAction.new()
	action.type = type
	action.value = value
	action.range_modifier = range_mod
	return action


func _make_monster_card(initiative: int, actions: Array) -> MonsterCard:
	var card := MonsterCard.new()
	card.card_name = "Test"
	card.initiative = initiative
	card.actions.assign(actions)
	return card


func _make_monster_deck(cards: Array, base_move := 63, base_attack := 6, base_range := 0) -> MonsterDeck:
	var deck := MonsterDeck.new()
	deck.base_move = base_move
	deck.base_attack = base_attack
	deck.base_range = base_range
	deck.cards.assign(cards)
	return deck


func _make_card_ai(state: CombatState, deck: MonsterDeck) -> CombatEnemyAI:
	var ai := _make_ai_full(state)
	ai.set_monster_deck(deck)
	ai.action_delay = 0.0
	return ai


func _make_condition(type: String, check_range: float = 12.0) -> AiCondition:
	var condition := AiCondition.new()
	condition.type = type
	condition.check_range = check_range
	return condition


func _make_action(type: String, score: float, conditions: Array) -> AiAction:
	var action := AiAction.new()
	action.action_type = type
	action.base_score = score
	for condition in conditions:
		action.conditions.append(condition)
	action.damage = 8
	return action

func before_each() -> void:
	_map = MockCombatMap.new()
	add_child(_map)
	_enemy_board = MockEnemyBoard.new()
	_enemy_board.map = _map

func after_each() -> void:
	_map.free()
	_map = null
	_enemy_board = null
