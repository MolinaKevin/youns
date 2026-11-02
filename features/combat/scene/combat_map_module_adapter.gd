class_name CombatMapModuleAdapter
extends RefCounted

var source: CombatMapObstacleAdapter

func _init(value: CombatMapObstacleAdapter = null) -> void: source = value
func module_at(pos: Vector2) -> Dictionary: return source.module_at(pos)
func obstacle_gap(obstacle: Dictionary) -> float: return source.obstacle_gap(obstacle)
func break_modules(obstacle: Dictionary, count: int) -> int: return source.break_modules(obstacle, count)
func build_modules(pos: Vector2, count: int) -> int: return source.build_modules(pos, count)
func slide_module(obstacle: Dictionary, direction: Vector2, distance: float) -> Dictionary: return source.slide_module(obstacle, direction, distance)
func throw_module(obstacle: Dictionary, target: Vector2) -> Dictionary: return source.throw_module(obstacle, target)
func collapse_modules_on_enemy() -> int: return source.collapse_modules_on_enemy()
func modules_adjacent_to_enemy() -> Array: return source.modules_adjacent_to_enemy()
