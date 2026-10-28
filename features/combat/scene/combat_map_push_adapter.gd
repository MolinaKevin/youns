class_name CombatMapPushAdapter
extends CombatMapPushPort

## Adaptador de empujes construido directamente sobre `CombatPushSystem`.
var _push_system: CombatPushSystem

func _init(push_system: CombatPushSystem) -> void:
	_push_system = push_system
	selection = CombatMapPushSelectionAdapter.new(self)
	queries = CombatMapPushQueriesAdapter.new(self)
	execution = CombatMapPushExecutionAdapter.new(self)
	modules = CombatMapPushModulesAdapter.new(self)
func start_push_enemy_selection(reach: float) -> void: _push_system.start_enemy_selection(reach)
func start_anchor_selection(reach: float, origin: Vector2) -> void: _push_system.map.presentation.combat_preview.show_range_at(origin, reach)
func start_push_cone(reach: float) -> void: _push_system.start_enemy_cone(reach)
func clear_push_selection() -> void: _push_system.clear_selection()
func is_pos_in_push_cone(pos: Vector2, reach: float) -> bool: return _push_system.is_pos_in_enemy_cone(pos, reach)
func calculate_push_landing(target: Vector2, reach: float) -> Vector2: return _push_system.calculate_push_landing(target, reach)
func calculate_drag_landing(target: Vector2, distance: float) -> Vector2: return _push_system.calculate_drag_landing(target, distance)
func push_enemy_to(landing: Vector2) -> void: _push_system.push_enemy_to(landing)
func start_module_push_cone(pos: Vector2, reach: float, half_angle: float) -> void: _push_system.start_module_cone(pos, reach, half_angle)
func is_pos_in_module_cone(origin: Vector2, pos: Vector2, reach: float, half_angle: float) -> bool: return _push_system.is_pos_in_module_cone(origin, pos, reach, half_angle)
