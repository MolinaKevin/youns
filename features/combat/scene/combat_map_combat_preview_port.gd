class_name CombatMapCombatPreviewPort
extends RefCounted

func show_push_enemy_selection(_grab_range: float) -> void: pass
func show_push_cone(_origin: Vector2, _direction: Vector2, _push_range: float, _half_angle: float) -> void: pass
func hide_attack_range() -> void: pass
func show_player_range(_radius: float) -> void: pass
func show_range_at(_center: Vector2, _radius: float) -> void: pass
func clear_push_selection() -> void: pass
func clear_module_selection() -> void: pass
