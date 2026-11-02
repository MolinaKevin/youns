class_name CombatMapStateAdapter
extends RefCounted

## Estado mutable mínimo que necesitan las acciones del tablero.
## No expone la escena ni las fachadas: sólo las posiciones de los actores.
const WORLD_W := 30.0
const WORLD_H := 30.0
const MIN_SEPARATION := 0.8
const CLICK_MARGIN := 0.6

## Adaptador del estado de actores de la escena concreta.
var _map: CombatMapArea

func _init(map: CombatMapArea) -> void:
	_map = map

func player_position() -> Vector2:
	return _map.player_pos

func set_player_position(pos: Vector2) -> void:
	_map.player_pos = pos

func enemy_position() -> Vector2:
	return _map.enemy_pos

func set_enemy_position(pos: Vector2) -> void:
	_map.enemy_pos = pos
