class_name CombatMapTargetingHoverAdapter
extends CombatMapTargetingHoverPort

var source: CombatMapTargetingPresentation
func _init(value: CombatMapTargetingPresentation) -> void: source = value
func show_move_preview(pos: Vector2) -> void: source.show_move_preview(pos)
func clear_move_preview() -> void: source.clear_move_preview()
func update_targeting_hover(pos: Vector2, enemy_hover: bool, self_hover: bool, show_cell: bool) -> void: source.update_targeting_hover(pos, enemy_hover, self_hover, show_cell)
func clear_targeting_hover() -> void: source.clear_targeting_hover()
