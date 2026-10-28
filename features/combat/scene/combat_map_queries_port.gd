class_name CombatMapQueriesPort
extends RefCounted

## Contrato de las consultas espaciales que consumen las reglas de combate.
## Las implementaciones reales pueden exponer utilidades extra, pero los
## resolvers sólo deben depender de estas operaciones de lectura.

func has_line_of_sight(_from: Vector2, _to: Vector2) -> bool:
	return false


func movement_distance(_from: Vector2, _to: Vector2) -> float:
	return 0.0


func actors_gap() -> float:
	return 0.0


func is_enemy_in_attack_range(_attack_range: float) -> bool:
	return false


func player_area_contact_radius() -> float:
	return 0.0


func enemy_area_contact_radius() -> float:
	return 0.0


func is_enemy_in_zones(_zones: Array) -> bool:
	return false


func is_player_in_zones(_zones: Array) -> bool:
	return false


func segment_hits_enemy(_from: Vector2, _to: Vector2) -> bool:
	return false


func is_enemy_in_cone(_origin: Vector2, _direction: Vector2, _cone_range: float, _half_angle_deg: float) -> bool:
	return false


func is_enemy_in_area_circle(_center: Vector2, _radius: float) -> bool:
	return false


func is_player_in_area_circle(_center: Vector2, _radius: float) -> bool:
	return false
