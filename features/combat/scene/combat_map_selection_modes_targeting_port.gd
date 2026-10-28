class_name CombatMapSelectionModesTargetingPort
extends RefCounted
func has_active_placement() -> bool: return false
func start_move_selection(_reach: float) -> void: pass
func clear_move_selection() -> void: pass
func start_attack_selection(_reach: float) -> void: pass
func clear_attack_selection() -> void: pass
