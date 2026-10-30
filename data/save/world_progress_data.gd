class_name WorldProgressData
extends Resource

## Progreso persistente del mundo exterior. Los nuevos puentes, warps y rutas
## desbloqueadas se agregan acá, sin inflar PlayerSaveData con flags sueltos.

@export var north_trail_open := false
## Misión de la guardacostas del Recodo. El objeto/receta se suma después;
## estos flags permiten bloquear la bajada desde ahora sin depender del visual.
@export var coastal_descent_mission_started := false
@export var coastal_descent_open := false
@export var tall_grass_mission_started := false
@export var tall_grass_route_open := false
## Misiones aceptadas desde NPCs o eventos. Los flags específicos de arriba se
## conservan mientras esas rutas todavía los consulten directamente.
@export var started_mission_ids: Array[String] = []
## Identificadores de estructuras construidas desde el laboratorio.
@export var unlocked_construction_ids: Array[String] = []
## Campo legado de partidas v2 y anteriores. Se migra a construction_ids.
## Retirar después de subir la versión mínima de guardado soportada y mantener
## una migración de importación para esos archivos antiguos.
@export var unlocked_bridge_ids: Array[String] = []


func unlock_construction(construction_id: String) -> void:
	if not construction_id.is_empty() and not unlocked_construction_ids.has(construction_id):
		unlocked_construction_ids.append(construction_id)


func has_construction(construction_id: String) -> bool:
	return unlocked_construction_ids.has(construction_id)


func start_mission(mission_id: String) -> void:
	if not mission_id.is_empty() and not started_mission_ids.has(mission_id):
		started_mission_ids.append(mission_id)


func has_mission(mission_id: String) -> bool:
	return started_mission_ids.has(mission_id)


func migrate_legacy_bridges() -> void:
	for bridge_id in unlocked_bridge_ids:
		unlock_construction(bridge_id)
	unlocked_bridge_ids.clear()
