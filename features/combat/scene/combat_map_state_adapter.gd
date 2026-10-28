class_name CombatMapStateAdapter
extends CombatMapStatePort

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
