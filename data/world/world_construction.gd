class_name WorldConstruction
extends Resource

## Estructura persistente construida al completar una receta del laboratorio.
@export var id := ""
@export var unlock_recipe_id := ""
@export var zone_id := ""
@export_file("*.tscn", "*.glb") var scene_path := ""
@export var node_name := ""
@export var position := Vector3.ZERO
## CollisionShape3D existente que bloquea el lugar antes de construir.
@export var blocker_path := NodePath("")
