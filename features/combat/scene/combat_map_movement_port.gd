class_name CombatMapMovementPort
extends RefCounted

## Operaciones de movimiento que consumen las acciones y la IA.
## La implementación concreta puede administrar navegación y waypoints sin
## obligar a los consumidores a conocer MapArea.

func try_move_player_to(_pos: Vector2) -> bool:
	return false

func plan_player_move(_pos: Vector2) -> String:
	return "no_path"

func path_cost() -> float:
	return 0.0

func move_enemy_toward(_target: Vector2, _move_range: float) -> bool:
	return false
