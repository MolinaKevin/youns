class_name CombatMapOverwatchSelectionPort
extends RefCounted

func start_overwatch_selection(_reach: float, _half_angle: float) -> void: pass
func clear_overwatch_selection() -> void: pass
func place_overwatch(_origin: Vector2, _direction: Vector2, _reach: float, _half_angle: float) -> void: pass
func clear_overwatch_zone() -> void: pass
func segment_is_in_overwatch_cone(_from: Vector2, _to: Vector2, _origin: Vector2, _direction: Vector2, _cone_range: float, _half_angle_deg: float) -> bool: return false
