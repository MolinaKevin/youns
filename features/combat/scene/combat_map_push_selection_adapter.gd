class_name CombatMapPushSelectionAdapter
extends RefCounted
var source
func _init(value) -> void: source = value
func start_push_enemy_selection(value: float) -> void: source.start_push_enemy_selection(value)
func start_anchor_selection(value: float, origin: Vector2) -> void: source.start_anchor_selection(value, origin)
func start_push_cone(value: float) -> void: source.start_push_cone(value)
func clear_push_selection() -> void: source.clear_push_selection()
