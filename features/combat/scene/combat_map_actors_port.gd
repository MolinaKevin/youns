class_name CombatMapActorsPort
extends RefCounted

## Contrato de gameplay para los actores del tablero. La configuración de
## modelos y waypoints queda en la implementación concreta.

func player_radius() -> float:
	return 0.0


func enemy_radius() -> float:
	return 0.0


func play_player_animation(_animation: String) -> void:
	pass


func play_enemy_animation(_animation: String) -> void:
	pass
