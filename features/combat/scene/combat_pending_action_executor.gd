class_name CombatPendingActionExecutor
extends RefCounted

## Ejecuta la acción pendiente actual sin conocer la selección de cartas ni la
## navegación de movimiento.

var _host

func _init(host) -> void:
	_host = host

func execute(cell: Vector2) -> void:
	if _host._current_action == null:
		return
	var action: CombatPendingAction = _host._current_action
	action.execute(cell)
	if not action.is_active():
		_host._current_action = null

func execute_async(cell: Vector2) -> void:
	if _host._current_action == null:
		return
	# Las implementaciones de `execute()` pueden ser corrutinas o inmediatas.
	# El puerto base es intencionalmente síncrono, por eso se despacha como
	# Variant para que `await` conserve la corrutina concreta cuando exista.
	var action: Variant = _host._current_action
	await action.execute(cell)
	if not action.is_active():
		_host._current_action = null

func active_index() -> int:
	return _host._current_action.index if _host._current_action != null else -1

func active_range_cells() -> int:
	if _host._current_action == null:
		return -1
	var range_value: Variant = _host._current_action.get("range_cells")
	return int(range_value) if range_value != null else -1
