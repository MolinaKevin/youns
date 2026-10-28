class_name CombatMapSelectionActionsAdapter
extends CombatMapSelectionActionsPort

var source: CombatMapSelectionAdapter
func _init(value: CombatMapSelectionAdapter) -> void: source = value
func start_rock_jump_selection(reach: float) -> void: source.start_rock_jump_selection(reach)
func clear_rock_jump_selection() -> void: source.clear_rock_jump_selection()
func start_jump_landing_selection(rock_pos: Vector2, reach: float) -> void: source.start_jump_landing_selection(rock_pos, reach)
func start_puddle_hop_landing(pos: Vector2, reach: float) -> void: source.start_puddle_hop_landing(pos, reach)
func start_module_selection(reach: float) -> void: source.start_module_selection(reach)
func clear_module_selection() -> void: source.clear_module_selection()
func start_collapse_selection(reach: float) -> void: source.start_collapse_selection(reach)
func start_module_throw_target(reach: float) -> void: source.start_module_throw_target(reach)
func start_spell_selection(reach: float) -> void: source.start_spell_selection(reach)
func start_overwatch_selection(reach: float, half_angle: float) -> void: source.start_overwatch_selection(reach, half_angle)
func clear_overwatch_selection() -> void: source.clear_overwatch_selection()
func place_overwatch(origin: Vector2, direction: Vector2, reach: float, half_angle: float) -> void: source.place_overwatch(origin, direction, reach, half_angle)
func clear_overwatch_zone() -> void: source.clear_overwatch_zone()
func segment_is_in_overwatch_cone(from: Vector2, to: Vector2, origin: Vector2, direction: Vector2, cone_range: float, half_angle_deg: float) -> bool:
	return source.segment_is_in_overwatch_cone(from, to, origin, direction, cone_range, half_angle_deg)
func clear_spell_selection() -> void: source.clear_spell_selection()
