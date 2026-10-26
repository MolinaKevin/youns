class_name WorldProgressData
extends Resource

## Progreso persistente del mundo exterior. Los nuevos puentes, warps y rutas
## desbloqueadas se agregan acá, sin inflar PlayerSaveData con flags sueltos.

@export var north_trail_open := false
## Identificadores de estructuras construidas desde el laboratorio.
@export var unlocked_construction_ids: Array[String] = []
## Campo legado de partidas v2 y anteriores. Se migra a construction_ids.
@export var unlocked_bridge_ids: Array[String] = []


func unlock_construction(construction_id: String) -> void:
	if not construction_id.is_empty() and not unlocked_construction_ids.has(construction_id):
		unlocked_construction_ids.append(construction_id)


func has_construction(construction_id: String) -> bool:
	return unlocked_construction_ids.has(construction_id)


func migrate_legacy_bridges() -> void:
	for bridge_id in unlocked_bridge_ids:
		unlock_construction(bridge_id)
	unlocked_bridge_ids.clear()


## Compatibilidad temporal para consumidores todavía no migrados.
func unlock_bridge(bridge_id: String) -> void:
	unlock_construction(bridge_id)


func has_bridge(bridge_id: String) -> bool:
	return has_construction(bridge_id)
