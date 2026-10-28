class_name CombatMapSelectionTargetingAdapter
extends CombatMapSelectionTargetingPort

var source: CombatMapSelectionAdapter
func _init(value: CombatMapSelectionAdapter) -> void:
	source = value
	hover = CombatMapSelectionHoverAdapter.new(self)
	modes = CombatMapSelectionModesTargetingAdapter.new(self)
	queries = CombatMapTargetQueriesAdapter.new(self)
func has_active_placement() -> bool: return source.has_active_placement()
func update_hover_previews(pos: Vector2) -> void: source.update_hover_previews(pos)
func update_hover(pos: Vector2) -> void: source.update_hover(pos)
func clear_hover() -> void: source.clear_hover()
func start_move_selection(reach: float) -> void: source.start_move_selection(reach)
func clear_move_selection() -> void: source.clear_move_selection()
func start_attack_selection(reach: float) -> void: source.start_attack_selection(reach)
func clear_attack_selection() -> void: source.clear_attack_selection()
func is_click_on_enemy(pos: Vector2) -> bool: return source.is_click_on_enemy(pos)
func is_click_on_player(pos: Vector2) -> bool: return source.is_click_on_player(pos)
func is_enemy_in_card_pattern(pattern: CardPattern, origin: Vector2, direction: Vector2, primary: float) -> bool:
	return source.is_enemy_in_card_pattern(pattern, origin, direction, primary)
