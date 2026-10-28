class_name CombatMapStatePort
extends RefCounted

## Estado mutable mínimo que necesitan las acciones del tablero.
## No expone la escena ni las fachadas: sólo las posiciones de los actores.
const WORLD_W := 30.0
const WORLD_H := 30.0
const MIN_SEPARATION := 0.8
const CLICK_MARGIN := 0.6

func player_position() -> Vector2:
	return Vector2.ZERO

func set_player_position(_pos: Vector2) -> void:
	pass

func enemy_position() -> Vector2:
	return Vector2.ZERO

func set_enemy_position(_pos: Vector2) -> void:
	pass
