class_name CombatEnemyBoardPort
extends RefCounted

## Contrato mínimo que necesita la IA enemiga para decidir y ejecutar un turno.
## No expone las fachadas generales del mapa: cada operación representa una
## necesidad concreta de la IA, lo que permite probarla sin una escena 3D.

func player_position() -> Vector2:
	return Vector2.ZERO

func enemy_position() -> Vector2:
	return Vector2.ZERO

func world_center() -> Vector2:
	return Vector2.ZERO

func clamp_to_world(pos: Vector2) -> Vector2:
	return pos

func has_line_of_sight(_from: Vector2, _to: Vector2) -> bool:
	return false

func movement_distance(from: Vector2, to: Vector2) -> float:
	return from.distance_to(to)

func actors_gap() -> float:
	return INF

func enemy_contact_radius() -> float:
	return 0.0

func trigger_enemy_traps() -> int:
	return 0

func move_enemy_toward(_target: Vector2, _move_range: float) -> bool:
	return false

func puddle_effects_along(_from: Vector2, _to: Vector2, _contact_margin: float) -> Dictionary:
	return {}

func puddle_damage_along(_from: Vector2, _to: Vector2, _contact_margin: float) -> Dictionary:
	return {}

func crosses_player_overwatch(_from: Vector2, _to: Vector2, _origin: Vector2, _direction: Vector2, _range: float, _half_angle: float) -> bool:
	return false

func clear_player_overwatch() -> void:
	pass
