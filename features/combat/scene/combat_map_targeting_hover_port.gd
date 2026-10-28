class_name CombatMapTargetingHoverPort
extends RefCounted

func show_move_preview(_pos: Vector2) -> void: pass
func clear_move_preview() -> void: pass
func update_targeting_hover(_pos: Vector2, _enemy_hover: bool, _self_hover: bool, _show_cell: bool) -> void: pass
func clear_targeting_hover() -> void: pass
