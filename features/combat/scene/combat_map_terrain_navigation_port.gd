class_name CombatMapTerrainNavigationPort
extends RefCounted

## Puerto mínimo para planificar y consultar rutas del tablero.
## La geometría y las reglas de obstáculos quedan fuera de este contrato.

func reachable_cells(_from: Vector2, _move_range: float, _elevation: int, _actor_radius: float, _blocked_by: Vector2, _blocked_radius: float) -> Array[Vector2i]:
	return []

func plan_move(_pos: Vector2, _elevation: int, _actor_radius: float, _blocked_by: Vector2, _blocked_radius: float) -> String:
	return "no_path"

func path_for_move(_pos: Vector2) -> Array[Vector2i]:
	return []

func clear_planned_path() -> void:
	pass

func planned_path() -> Array[Vector2]:
	return []

func planned_path_cost() -> float:
	return 0.0

func find_toward(_from: Vector2, _target: Vector2, _move_range: float, _elevation: int, _actor_radius: float, _blocked_by: Vector2, _blocked_radius: float) -> Dictionary:
	return {}
