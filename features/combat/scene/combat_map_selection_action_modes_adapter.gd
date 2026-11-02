class_name CombatMapSelectionActionModesAdapter
extends RefCounted
var source
func _init(value) -> void: source = value
func start_module_selection(value: float) -> void: source.start_module_selection(value)
func clear_module_selection() -> void: source.clear_module_selection()
func start_collapse_selection(value: float) -> void: source.start_collapse_selection(value)
func start_module_throw_target(value: float) -> void: source.start_module_throw_target(value)
func start_spell_selection(value: float) -> void: source.start_spell_selection(value)
func clear_spell_selection() -> void: source.clear_spell_selection()
