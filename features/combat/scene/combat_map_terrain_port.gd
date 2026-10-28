class_name CombatMapTerrainPort
extends RefCounted

## Consultas y mutaciones del terreno que necesitan las acciones de combate.
## Los detalles de navegación, cachés y obstáculos quedan detrás de este
## contrato y pueden reemplazarse por dobles pequeños en tests.

func obstacles() -> Array[Dictionary]:
	return []

func obstacle_snapshot() -> Array[Dictionary]:
	return []

func add_obstacle(_obstacle: Dictionary) -> void:
	pass

func remove_obstacle(_obstacle: Dictionary) -> void:
	pass

func obstacles_changed() -> void:
	pass

func is_inside_bounds(_pos: Vector2, _margin: float = 0.0) -> bool:
	return false

func clamp_to_bounds(pos: Vector2, _margin: float = 0.0) -> Vector2:
	return pos

func platforms() -> Array[Dictionary]:
	return []

func bounds_travel_fraction(_from: Vector2, _to: Vector2, _margin: float) -> float:
	return 0.0

func elevation_at(_pos: Vector2) -> int:
	return 0

func has_line_of_sight(_from: Vector2, _to: Vector2) -> bool:
	return false

func movement_distance(from: Vector2, to: Vector2) -> float:
	return from.distance_to(to)

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

func player_height_at(_pos: Vector2, _elevation: int) -> float:
	return 0.0

func elevation_height(elevation: int) -> float:
	return float(elevation) * 1.5

func height_at(_pos: Vector2) -> float:
	return 0.0

func warm_caches(_first_radius: float, _second_radius: float) -> void:
	pass

func player_contact_radius() -> float:
	return 0.0

func enemy_contact_radius() -> float:
	return 0.0

func clip_path_at_obstacle(_from: Vector2, to: Vector2) -> Vector2:
	return to

func is_blocked(_pos: Vector2, _elevation: int = 0, _margin: float = 0.5) -> bool:
	return false

func is_tile_obstructed(_pos: Vector2, _elevation: int = 0) -> bool:
	return false

func can_blink_to(_pos: Vector2) -> bool:
	return false
