class_name ZoneDefinition
extends Resource

## Descripción estática de una zona exterior. No contiene nodos cargados ni
## estado de juego: sólo el contrato que usa ZoneCatalog y ZoneManager.

@export var id := ""
@export_file("*.tscn") var scene_path := ""
@export var offset := Vector3.ZERO
@export var connections: Array[String] = []
