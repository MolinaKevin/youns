class_name MockCombatPush
extends CombatMapPushPort

var owner

func _init() -> void:
	selection = CombatMapPushSelectionAdapter.new(self)
	queries = CombatMapPushQueriesAdapter.new(self)
	execution = CombatMapPushExecutionAdapter.new(self)
	modules = CombatMapPushModulesAdapter.new(self)

func start_push_enemy_selection(_reach: float) -> void: pass
func start_anchor_selection(_reach: float, _origin: Vector2) -> void: pass
func start_push_cone(_reach: float) -> void: pass
func clear_push_selection() -> void: pass
func is_pos_in_push_cone(_pos: Vector2, _reach: float) -> bool: return true
func calculate_push_landing(target: Vector2, _reach: float) -> Vector2: return target
func calculate_drag_landing(target: Vector2, _distance: float) -> Vector2: return target
func push_enemy_to(landing: Vector2) -> void:
	owner.push_enemy_to_calls.append(landing)
	owner.enemy_pos = landing
	owner.enemy_reached_target.emit.call_deferred()
func start_module_push_cone(_pos: Vector2, _reach: float, _angle: float) -> void: pass
func is_pos_in_module_cone(_origin: Vector2, _pos: Vector2, _reach: float, _angle: float) -> bool: return true
