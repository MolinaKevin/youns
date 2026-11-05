class_name CombatPendingActionExecutor
extends RefCounted

## Ejecuta la acción pendiente actual sin conocer la selección de cartas ni la
## navegación de movimiento.

var _host

func _init(host) -> void:
	_host = host

func execute(cell: Vector2) -> void:
	var action: CombatPendingAction = _host.current_action()
	if action == null:
		return
	if action is CombatMoveAction:
		print("[CombatMoveTrace] executor.before_execute | cell=%s active=%s current_is_move=%s" % [cell, action.is_active(), _host.current_action() == action])
	action.execute(cell)
	if action is CombatMoveAction:
		print("[CombatMoveTrace] executor.after_execute | active=%s current_is_move=%s" % [action.is_active(), _host.current_action() == action])
	if not action.is_active():
		if action is CombatMoveAction:
			print("[CombatMoveTrace] executor.clear_current_action")
		_host.clear_current_action()
		if action is CombatMoveAction:
			print("[CombatMoveTrace] executor.current_action_cleared | current=%s" % _host.current_action())

func execute_async(cell: Vector2) -> void:
	# Las implementaciones de `execute()` pueden ser corrutinas o inmediatas.
	# El puerto base es intencionalmente síncrono, por eso se despacha como
	# Variant para que `await` conserve la corrutina concreta cuando exista.
	var action: Variant = _host.current_action()
	if action == null:
		return
	await action.execute(cell)
	if not action.is_active():
		_host.clear_current_action()

func active_index() -> int:
	var action: CombatPendingAction = _host.current_action()
	return action.index if action != null else -1

func active_range_cells() -> int:
	var action: CombatPendingAction = _host.current_action()
	if action == null:
		return -1
	var range_value: Variant = action.get("range_cells")
	return int(range_value) if range_value != null else -1
