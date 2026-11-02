class_name CombatMapTargetingOverlayAdapter
extends RefCounted

var ranges: CombatMapTargetingRangeAdapter
var path: CombatMapTargetingPathAdapter
var actors: CombatMapTargetingActorHighlightsAdapter

var source: CombatMapTargetingPresentation
func _init(value: CombatMapTargetingPresentation = null) -> void:
	source = value
	ranges = CombatMapTargetingRangeAdapter.new(self)
	path = CombatMapTargetingPathAdapter.new(self)
	actors = CombatMapTargetingActorHighlightsAdapter.new(self)
func show_move_selection(cells: Array[Vector2i]) -> void: source.show_move_selection(cells)
func clear_move_selection() -> void: source.clear_move_selection()
func show_path_preview() -> void: source.show_path_preview()
func clear_path_preview() -> void: source.clear_path_preview()
func show_attack_selection(attack_range: float) -> void: source.show_attack_selection(attack_range)
func clear_attack_selection() -> void: source.clear_attack_selection()
func show_enemy_highlight() -> void: source.show_enemy_highlight()
func clear_enemy_highlight() -> void: source.clear_enemy_highlight()
func show_self_highlight() -> void: source.show_self_highlight()
func clear_self_highlight() -> void: source.clear_self_highlight()
func has_active_targeting_overlay() -> bool: return source.has_active_targeting_overlay()
func has_enemy_targeting_overlay() -> bool: return source.has_enemy_targeting_overlay()
func has_self_targeting_overlay() -> bool: return source.has_self_targeting_overlay()
