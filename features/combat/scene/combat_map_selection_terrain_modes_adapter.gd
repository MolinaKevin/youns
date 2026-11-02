class_name CombatMapSelectionTerrainModesAdapter
extends RefCounted
var source
func _init(value) -> void: source = value
func start_rock_jump_selection(value: float) -> void: source.start_rock_jump_selection(value)
func clear_rock_jump_selection() -> void: source.clear_rock_jump_selection()
func start_jump_landing_selection(pos: Vector2, value: float) -> void: source.start_jump_landing_selection(pos, value)
func start_puddle_hop_landing(pos: Vector2, value: float) -> void: source.start_puddle_hop_landing(pos, value)
