class_name CombatMapModulePort
extends RefCounted

func module_at(_pos: Vector2) -> Dictionary: return {}
func obstacle_gap(_obstacle: Dictionary) -> float: return 0.0
func break_modules(_obstacle: Dictionary, _count: int) -> int: return 0
func build_modules(_pos: Vector2, _count: int) -> int: return 0
func slide_module(obstacle: Dictionary, _direction: Vector2, _distance: float) -> Dictionary: return obstacle
func throw_module(obstacle: Dictionary, _target: Vector2) -> Dictionary: return obstacle
func collapse_modules_on_enemy() -> int: return 0
func modules_adjacent_to_enemy() -> Array: return []
