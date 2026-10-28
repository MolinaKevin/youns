class_name CombatMapOverwatchSelectionAdapter
extends CombatMapOverwatchSelectionPort
var source
func _init(value: CombatMapSelectionActionsPort) -> void: source = value
func start_overwatch_selection(value: float, angle: float) -> void: source.start_overwatch_selection(value, angle)
func clear_overwatch_selection() -> void: source.clear_overwatch_selection()
func place_overwatch(origin: Vector2, direction: Vector2, reach: float, angle: float) -> void: source.place_overwatch(origin, direction, reach, angle)
func clear_overwatch_zone() -> void: source.clear_overwatch_zone()
func segment_is_in_overwatch_cone(from: Vector2, to: Vector2, origin: Vector2, direction: Vector2, reach: float, angle: float) -> bool:
	return source.segment_is_in_overwatch_cone(from, to, origin, direction, reach, angle)
