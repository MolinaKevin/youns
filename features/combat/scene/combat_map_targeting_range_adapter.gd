class_name CombatMapTargetingRangeAdapter
extends RefCounted
var source
func _init(value = null) -> void: source = value
func show_move_selection(cells: Array[Vector2i]) -> void: source.show_move_selection(cells)
func clear_move_selection() -> void: source.clear_move_selection()
func show_attack_selection(value: float) -> void: source.show_attack_selection(value)
func clear_attack_selection() -> void: source.clear_attack_selection()
