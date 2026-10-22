class_name BiomeData
extends Resource

## Datos de un bioma del mundo. También define cómo se arma el tablero de
## combate correspondiente; las reglas genéricas siguen viviendo en MapArea.
@export var id: String = ""
@export var combat_layout: CombatBiomeLayout

## Entrega a MapArea los obstáculos lógicos del bioma. Se hace antes de _ready,
## por lo que el mapa puede construir sus visuales con el layout correcto.
func setup_combat_map(map: Node3D) -> void:
	if combat_layout != null:
		combat_layout.populate_map(map)

## Construye los elementos visuales que están por encima del suelo una vez que
## MapArea ya está listo. Cada layout es dueño de esas decisiones estéticas.
func build_combat_map(map: Node3D) -> void:
	if combat_layout != null:
		combat_layout.build_visuals(map)
