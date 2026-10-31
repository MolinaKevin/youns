class_name CombatTrapData
extends RefCounted

## Trampa de un solo uso del tablero. Antes era un Dictionary compartido por
## lógica y presentación; este contrato hace explícitos sus cuatro datos.

var position: Vector2
var radius: float
var damage: int
var source_name: String


func _init(p_position: Vector2, p_radius: float, p_damage: int, p_source_name: String) -> void:
	position = p_position
	radius = p_radius
	damage = p_damage
	source_name = p_source_name
