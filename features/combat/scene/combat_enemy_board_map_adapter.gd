class_name CombatEnemyBoardMapAdapter
extends CombatEnemyBoardPort

## Adaptador temporal entre la IA enemiga y el tablero concreto. Mantiene el
## conocimiento de MapArea fuera de CombatEnemyAI y de sus dos estrategias.

var map_area: CombatMapArea

func _init(p_map_area: CombatMapArea) -> void:
	map_area = p_map_area
	state = CombatEnemyBoardStateAdapter.new(self)
	queries = CombatEnemyBoardQueriesAdapter.new(self)
	effects = CombatEnemyBoardEffectsAdapter.new(self)
	movement = CombatEnemyBoardMovementAdapter.new(self)

func player_position() -> Vector2:
	return map_area.player_pos

func enemy_position() -> Vector2:
	return map_area.enemy_pos

func world_center() -> Vector2:
	return Vector2(map_area.WORLD_W * 0.5, map_area.WORLD_H * 0.5)

func clamp_to_world(pos: Vector2) -> Vector2:
	return Vector2(clampf(pos.x, 0.0, map_area.WORLD_W), clampf(pos.y, 0.0, map_area.WORLD_H))

func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	return map_area.queries.line_of_sight.has_line_of_sight(from, to)

func movement_distance(from: Vector2, to: Vector2) -> float:
	return map_area.queries.actors.movement_distance(from, to)

func actors_gap() -> float:
	return map_area.queries.actors.actors_gap()

func enemy_contact_radius() -> float:
	return map_area.queries.actors.enemy_area_contact_radius()

func trigger_enemy_traps() -> int:
	return map_area.effects.traps.trigger_traps(map_area.enemy_pos)

func move_enemy_toward(target: Vector2, move_range: float) -> bool:
	return map_area.movement.move_enemy_toward(target, move_range)

func puddle_effects_along(from: Vector2, to: Vector2, contact_margin: float) -> Dictionary:
	return map_area.effects.puddle_port.zones.puddle_effects_along(from, to, contact_margin)

func puddle_damage_along(from: Vector2, to: Vector2, contact_margin: float) -> Dictionary:
	return map_area.effects.puddle_port.zones.puddle_damage_along(from, to, contact_margin)

func crosses_player_overwatch(from: Vector2, to: Vector2, origin: Vector2, direction: Vector2, cone_range: float, half_angle: float) -> bool:
	return map_area.selection.actions.overwatch.segment_is_in_overwatch_cone(from, to, origin, direction, cone_range, half_angle)

func clear_player_overwatch() -> void:
	map_area.selection.actions.overwatch.clear_overwatch_zone()
