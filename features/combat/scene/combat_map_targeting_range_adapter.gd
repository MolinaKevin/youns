class_name CombatMapTargetingRangeAdapter
extends CombatMapTargetingRangePort
var source
func _init(value) -> void: source = value
func show_move_selection(cells: Array[Vector2i]) -> void: source.show_move_selection(cells)
func clear_move_selection() -> void: source.clear_move_selection()
func show_attack_selection(value: float) -> void: source.show_attack_selection(value)
func clear_attack_selection() -> void: source.clear_attack_selection()
