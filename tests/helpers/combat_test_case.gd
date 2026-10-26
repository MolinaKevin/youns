extends GutTest

## Base común para pruebas de combate que necesitan un tablero controlado.
## Mantiene el doble separado de los casos, para que las pruebas se agrupen
## por comportamiento y no por el tamaño del mock.

class MockMapArea extends CombatMapArea:
	class MockQueries extends RefCounted:
		var owner: MockMapArea

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
		func actors_gap() -> float: return owner.actors_gap()
		func player_area_contact_radius() -> float: return owner.player_area_contact_radius()
		func enemy_area_contact_radius() -> float: return owner.enemy_area_contact_radius()
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

	class MockActors extends RefCounted:
		var owner: MockMapArea
		func play_player_animation(_animation: String) -> void: owner.player_anim_finished.emit.call_deferred()
		func play_enemy_animation(_animation: String) -> void: owner.enemy_anim_finished.emit.call_deferred()

	class MockPresentation extends RefCounted:
		var owner: MockMapArea
		func show_card_pattern(_pattern: CardPattern, _origin: Vector2, _direction: Vector2, _primary: float) -> void: pass
		func clear_card_pattern() -> void: pass
		func show_path_preview() -> void: pass
		func clear_path_preview() -> void: pass
		func show_enemy_highlight() -> void: pass
		func clear_enemy_highlight() -> void: pass
		func show_self_highlight() -> void: pass
		func clear_self_highlight() -> void: pass

	class MockInteractions extends RefCounted:
		var owner: MockMapArea
		func puddle_effects_along(from: Vector2, to: Vector2, contact_margin := 0.0) -> Dictionary:
			return owner.get_puddle_effects_along(from, to, contact_margin)
		func zone_effects_along(from: Vector2, to: Vector2, contact_margin := 0.0) -> Dictionary:
			return owner.trigger_zone_effects_along(from, to, contact_margin)
		func puddle_damage_along(from: Vector2, to: Vector2, contact_margin := 0.0) -> Dictionary:
			return owner.get_puddle_damage_along(from, to, contact_margin)
		func is_tree_near(pos: Vector2, reach: float) -> bool:
			return owner.is_tree_near(pos, reach)
		func start_move_selection(reach: float) -> void: owner.start_move_selection(reach)
		func clear_move_selection() -> void: owner.clear_move_selection()
		func start_attack_selection(reach: float) -> void: owner.start_attack_selection(reach)
		func clear_attack_selection() -> void: owner.clear_attack_selection()
		func start_trap_placement(reach: float, radius := 1.0, preview_los := true) -> void: owner.start_trap_placement(reach, radius, preview_los)
		func clear_trap_placement() -> void: owner.clear_trap_placement()
		func place_trap(pos: Vector2, radius: float, damage: int, card_name: String) -> void: owner.place_trap(pos, radius, damage, card_name)
		func trigger_traps(pos: Vector2, _contact_margin := 0.0) -> int: return owner.check_and_trigger_traps(pos)
		func trigger_traps_along(from: Vector2, to: Vector2, contact_margin := 0.0) -> int:
			return owner.check_and_trigger_traps_along_path(from, to, contact_margin)
		func grenade_landing(from: Vector2, target: Vector2, bounce: float) -> Vector2: return owner.calculate_grenade_landing(from, target, bounce)
		func show_grenade_preview(landing: Vector2, radius: float) -> void: owner.show_grenade_preview(landing, radius)
		func clear_grenade_preview() -> void: owner.clear_grenade_preview()
		func is_enemy_in_explosion(center: Vector2, radius: float) -> bool: return owner.is_enemy_in_explosion(center, radius)
		func start_rock_jump_selection(reach: float) -> void: owner.start_rock_jump_selection(reach)
		func clear_rock_jump_selection() -> void: owner.clear_rock_jump_selection()
		func rocks_in_range(origin: Vector2, reach: float) -> Array[Dictionary]: return owner.get_rocks_in_range(origin, reach)
		func rock_near(pos: Vector2) -> Dictionary: return owner.get_rock_near(pos)
		func start_jump_landing_selection(rock_pos: Vector2, reach: float) -> void: owner.start_jump_landing_selection(rock_pos, reach)
		func can_jump_land_at(pos: Vector2) -> bool: return owner.can_jump_land_at(pos)
		func land_player_from_jump(pos: Vector2) -> void: owner.land_player_from_jump(pos)
		func is_enemy_near(pos: Vector2, radius: float) -> bool: return owner.is_enemy_near_pos(pos, radius)
		func start_puddle_placement(reach: float, effect: String, radius: float) -> void: owner.start_puddle_placement(reach, effect, radius)
		func clear_puddle_placement() -> void: owner.clear_puddle_placement()
		func place_puddle(pos: Vector2, radius: float, effect: String, turns: int, damage: int) -> void: owner.place_puddle(pos, radius, effect, turns, damage)
		func tick_puddles() -> void: pass
		func puddle_at(_pos: Vector2) -> Dictionary: return {}
		func start_puddle_hop_landing(_pos: Vector2, _reach: float) -> void: pass
		func start_overwatch_selection(reach: float, angle: float) -> void: owner.start_overwatch_selection(reach, angle)
		func clear_overwatch_selection() -> void: owner.clear_overwatch_selection()
		func place_overwatch(origin: Vector2, direction: Vector2, reach: float, angle: float) -> void: owner.place_overwatch(origin, direction, reach, angle)
		func clear_overwatch_zone() -> void: owner.clear_overwatch_zone()
		func segment_is_in_overwatch_cone(from: Vector2, to: Vector2, origin: Vector2, dir: Vector2, cone_range: float, half_angle_deg: float) -> bool:
			return owner.is_segment_in_overwatch_cone(from, to, origin, dir, cone_range, half_angle_deg)
		func start_push_enemy_selection(reach: float) -> void: owner.start_push_enemy_selection(reach)
		func start_anchor_selection(reach: float, _origin: Vector2) -> void: owner.start_anchor_selection(reach)
		func start_push_cone(reach: float) -> void: owner.start_push_cone(reach)
		func clear_push_selection() -> void: owner.clear_push_selection()
		func is_pos_in_push_cone(pos: Vector2, reach: float) -> bool: return owner.is_pos_in_push_cone(pos, reach)
		func calculate_push_landing(target: Vector2, reach: float) -> Vector2: return owner.calculate_push_landing(target, reach)
		func calculate_drag_landing(target: Vector2, reach: float) -> Vector2: return owner.calculate_drag_landing(target, reach)
		func push_enemy_to(pos: Vector2) -> void: owner.push_enemy_to(pos)
		func start_module_selection(reach: float) -> void: owner.start_module_selection(reach)
		func clear_module_selection() -> void: owner.clear_module_selection()
		func start_collapse_selection(reach: float) -> void: owner.start_collapse_selection(reach)
		func start_module_throw_target(_reach: float) -> void: pass
		func start_module_push_cone(_pos: Vector2, _reach: float, _angle: float) -> void: pass
		func is_pos_in_module_cone(_origin: Vector2, _pos: Vector2, _reach: float, _angle: float) -> bool: return true
		func module_at(pos: Vector2) -> Dictionary: return owner.get_module_at(pos)
		func obstacle_gap(obstacle: Dictionary) -> float: return owner.obstacle_gap(obstacle)
		func break_modules(obstacle: Dictionary, count: int) -> int: return owner.break_modules(obstacle, count)
		func build_modules(pos: Vector2, count: int) -> int: return owner.build_modules(pos, count)
		func slide_module(_obstacle: Dictionary, _direction: Vector2, _distance: float) -> Dictionary: return {"hit": "", "tree": {}}
		func throw_module(_obstacle: Dictionary, _target: Vector2) -> Dictionary: return {"enemy": false, "player": false}
		func collapse_modules_on_enemy() -> int: return 0
		func start_spell_selection(reach: float) -> void: owner.start_spell_selection(reach)
		func clear_spell_selection() -> void: owner.clear_spell_selection()
		func place_delayed_zone(pos: Vector2, radius: float, damage: int, name: String, rounds: int, effect: String, duration: int) -> void: owner.place_delayed_zone(pos, radius, damage, name, rounds, effect, duration)
		func blink_player_to(pos: Vector2) -> void: owner.blink_player_to(pos)
		func tree_at(pos: Vector2) -> Dictionary: return owner.get_tree_at(pos)
		func can_drop_at(_pos: Vector2) -> bool: return true
		func is_tree_burning(_tree: Dictionary) -> bool: return false
		func tick_trees() -> void: pass
		func is_click_on_enemy(pos: Vector2) -> bool: return owner.is_click_on_enemy(pos)
		func is_click_on_player(_pos: Vector2) -> bool: return true
		func is_enemy_in_card_pattern(_pattern: CardPattern, _origin: Vector2, _direction: Vector2, _primary: float) -> bool: return true

	class MockTerrain extends RefCounted:
		var owner: MockMapArea
		func can_blink_to(pos: Vector2) -> bool: return owner.can_blink_to(pos)

	class MockMovement extends RefCounted:
		var owner: MockMapArea
		func move_enemy_toward(target: Vector2, move_range: float) -> bool:
			return owner.move_enemy_toward(target, move_range)
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
	var actors: MockActors
	var presentation: MockPresentation
	var terrain: MockTerrain

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

	func movement_distance(a: Vector2, b: Vector2) -> float: return queries.movement_distance(a, b)
	func has_line_of_sight(a: Vector2, b: Vector2) -> bool: return queries.has_line_of_sight(a, b)
	func check_and_trigger_traps(_pos: Vector2) -> int: return 0
	func check_and_trigger_traps_along_path(_from: Vector2, _to: Vector2, _contact_margin := 0.0) -> int: return 0
	func player_area_contact_radius() -> float: return 0.0
	func enemy_area_contact_radius() -> float: return 0.0
	func start_self_highlight() -> void: pass
	func clear_self_highlight() -> void: pass
	func start_attack_selection(_range: float) -> void: pass
	func clear_attack_selection() -> void: pass
	func clear_path_preview() -> void: presentation.clear_path_preview()
	func clear_move_selection() -> void: pass
	func move_enemy_toward(_target: Vector2, _move_range: float) -> bool:
		move_enemy_toward_calls += 1
		return true
	func get_puddle_effects_along(_from: Vector2, _to: Vector2, _contact_margin := 0.0) -> Dictionary: return puddle_effects_result
	func get_puddle_damage_along(_from: Vector2, _to: Vector2, _contact_margin := 0.0) -> Dictionary: return puddle_damage_result
	func trigger_zone_effects_along(_from: Vector2, _to: Vector2, _contact_margin := 0.0) -> Dictionary: return puddle_effects_result
	func start_move_selection(_range: float) -> void: start_move_selection_calls += 1
	func start_puddle_placement(_throw_range: float, _effect := "wet", _radius := 1.0) -> void: pass
	func clear_puddle_placement() -> void: pass
	func place_puddle(pos: Vector2, radius: float, effect := "wet", turns := 0, damage := 0) -> void:
		place_puddle_calls.append({"pos": pos, "radius": radius, "effect": effect, "turns": turns, "damage": damage})
	func start_overwatch_selection(_cone_range: float, _half_angle: float) -> void: pass
	func clear_overwatch_selection() -> void: pass
	func place_overwatch(_origin: Vector2, _dir: Vector2, _cone_range: float, _half_angle: float) -> void: pass
	func clear_overwatch_zone() -> void: clear_overwatch_zone_calls += 1
	func is_enemy_in_attack_range(_range: float) -> bool: return true
	func actors_gap() -> float: return player_pos.distance_to(enemy_pos) - 1.3
	func is_segment_in_overwatch_cone(_from: Vector2, _to: Vector2, _origin: Vector2, _dir: Vector2, _cone_range: float, _half_angle_deg: float) -> bool: return overwatch_cone_hit
	func clear_card_pattern_preview() -> void: presentation.clear_card_pattern()

	func start_trap_placement(_a, _b := 0.0, _previsualize_line_of_sight := true) -> void: pass
	func clear_trap_placement() -> void: pass
	func place_trap(pos: Vector2, radius: float, damage: int, card_name: String) -> void:
		place_trap_calls.append({"pos": pos, "radius": radius, "damage": damage, "name": card_name})
	func calculate_grenade_landing(_from: Vector2, target: Vector2, _bounce: float) -> Vector2: return target
	func show_grenade_preview(_landing: Vector2, _radius: float) -> void: pass
	func clear_grenade_preview() -> void: pass
	func is_enemy_in_explosion(_center: Vector2, _radius: float) -> bool: return true

	const MIN_SEPARATION := 0.1
	func get_rocks_in_range(_origin: Vector2, _range: float) -> Array[Dictionary]: return [{"pos": Vector2(5.0, 0.0)}]
	func start_rock_jump_selection(_range: float) -> void: pass
	func get_rock_near(pos: Vector2) -> Dictionary: return {"pos": pos}
	func start_jump_landing_selection(_rock_pos: Vector2, _range: float) -> void: pass
	func can_jump_land_at(_pos: Vector2) -> bool: return true
	func clear_rock_jump_selection() -> void: pass
	func land_player_from_jump(pos: Vector2) -> void: player_pos = pos
	func is_enemy_near_pos(pos: Vector2, radius: float) -> bool: return pos.distance_to(enemy_pos) <= radius

	func play_player_anim(anim: String) -> void: actors.play_player_animation(anim)
	func play_enemy_anim(anim: String) -> void: actors.play_enemy_animation(anim)
	func push_enemy_to(pos: Vector2) -> void:
		push_enemy_to_calls.append(pos)
		enemy_pos = pos
		enemy_reached_target.emit.call_deferred()
	func calculate_push_landing(target: Vector2, _range: float) -> Vector2: return target
	func calculate_drag_landing(target: Vector2, _range: float) -> Vector2: return target
	func clear_push_selection() -> void: pass
	func start_push_enemy_selection(_range: float) -> void: pass
	func start_anchor_selection(_range: float) -> void: pass
	func start_push_cone(_range: float) -> void: pass
	func is_click_on_enemy(_pos: Vector2) -> bool: return true
	func is_pos_in_push_cone(_pos: Vector2, _range: float) -> bool: return true

	func start_module_selection(_range: float) -> void: pass
	func start_collapse_selection(_range: float) -> void: pass
	func clear_module_selection() -> void: pass
	func get_module_at(_pos: Vector2) -> Dictionary: return {}
	func get_tree_at(_pos: Vector2) -> Dictionary: return {}
	func obstacle_gap(_obs: Dictionary) -> float: return 0.0
	func build_modules(pos: Vector2, count: int) -> int:
		build_modules_calls.append({"pos": pos, "count": count})
		return count
	func break_modules(obs: Dictionary, count: int) -> int:
		break_modules_calls.append({"obs": obs, "count": count})
		return count

	func start_spell_selection(_range: float) -> void: pass
	func clear_spell_selection() -> void: pass
	func can_blink_to(_pos: Vector2) -> bool: return true
	func blink_player_to(pos: Vector2) -> void: blink_calls.append(pos)
	func place_delayed_zone(pos: Vector2, radius: float, damage: int, _card_name: String, delay: int, effect: String, duration: int) -> void:
		place_delayed_zone_calls.append({"pos": pos, "radius": radius, "damage": damage, "delay": delay, "effect": effect, "duration": duration})
	func is_tree_near(_pos: Vector2, _range: float) -> bool: return false


var _map: MockMapArea


func _make_ai(p_state: CombatState) -> CombatEnemyAI:
	var ai := CombatEnemyAI.new()
	ai.setup(p_state, _map, null, Callable(), Callable(), Callable())
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
	ai.setup(state, _map, strategy, _dmg_enemy_callable(state), _dmg_player_callable(state), _check_end_callable(state))
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
	_map = MockMapArea.new()
	add_child(_map)

func after_each() -> void:
	_map.free()
	_map = null
