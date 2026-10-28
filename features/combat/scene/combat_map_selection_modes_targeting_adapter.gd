class_name CombatMapSelectionModesTargetingAdapter
extends CombatMapSelectionModesTargetingPort
var source
func _init(value) -> void: source = value
func has_active_placement() -> bool: return source.has_active_placement()
func start_move_selection(value: float) -> void: source.start_move_selection(value)
func clear_move_selection() -> void: source.clear_move_selection()
func start_attack_selection(value: float) -> void: source.start_attack_selection(value)
func clear_attack_selection() -> void: source.clear_attack_selection()
