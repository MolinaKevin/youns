class_name CombatMapSelectionModesAdapter
extends CombatMapSelectionModesPort
var source
func _init(value: CombatMapSelectionActionsPort) -> void:
	source = value
	terrain = CombatMapSelectionTerrainModesAdapter.new(self)
	actions = CombatMapSelectionActionModesAdapter.new(self)
func start_rock_jump_selection(value: float) -> void: source.start_rock_jump_selection(value)
func clear_rock_jump_selection() -> void: source.clear_rock_jump_selection()
func start_jump_landing_selection(pos: Vector2, value: float) -> void: source.start_jump_landing_selection(pos, value)
func start_puddle_hop_landing(pos: Vector2, value: float) -> void: source.start_puddle_hop_landing(pos, value)
func start_module_selection(value: float) -> void: source.start_module_selection(value)
func clear_module_selection() -> void: source.clear_module_selection()
func start_collapse_selection(value: float) -> void: source.start_collapse_selection(value)
func start_module_throw_target(value: float) -> void: source.start_module_throw_target(value)
func start_spell_selection(value: float) -> void: source.start_spell_selection(value)
func clear_spell_selection() -> void: source.clear_spell_selection()
