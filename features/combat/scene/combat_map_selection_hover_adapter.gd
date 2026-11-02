class_name CombatMapSelectionHoverAdapter
extends RefCounted
var source
func _init(value) -> void: source = value
func update_hover_previews(pos: Vector2) -> void: source.update_hover_previews(pos)
func update_hover(pos: Vector2) -> void: source.update_hover(pos)
func clear_hover() -> void: source.clear_hover()
