class_name CombatMapPushModulesAdapter
extends CombatMapPushModulesPort
var source
func _init(value) -> void: source = value
func start_module_push_cone(pos: Vector2, reach: float, angle: float) -> void: source.start_module_push_cone(pos, reach, angle)
func is_pos_in_module_cone(origin: Vector2, pos: Vector2, reach: float, angle: float) -> bool: return source.is_pos_in_module_cone(origin, pos, reach, angle)
