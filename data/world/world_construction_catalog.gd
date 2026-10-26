class_name WorldConstructionCatalog
extends RefCounted

const WorldConstruction := preload("res://data/world/world_construction.gd")
const CONSTRUCTIONS_DIR := "res://data/world/constructions"

var _by_id: Dictionary = {}
var _load_errors := PackedStringArray()


func _init() -> void:
	var paths := DirAccess.get_files_at(CONSTRUCTIONS_DIR)
	paths.sort()
	for filename in paths:
		if not filename.ends_with(".tres"):
			continue
		var construction := load(CONSTRUCTIONS_DIR.path_join(filename)) as WorldConstruction
		if construction == null or construction.id.is_empty():
			_load_errors.append("Construcción inválida '%s'." % filename)
			continue
		if _by_id.has(construction.id):
			_load_errors.append("Id de construcción duplicado '%s'." % construction.id)
			continue
		_by_id[construction.id] = construction


func for_zone(target_zone_id: String) -> Array[WorldConstruction]:
	var result: Array[WorldConstruction] = []
	for construction in _by_id.values():
		if construction.zone_id == target_zone_id:
			result.append(construction)
	return result


func all() -> Array[WorldConstruction]:
	var result: Array[WorldConstruction] = []
	for construction in _by_id.values():
		result.append(construction)
	return result


func unlock_completed(progress: WorldProgressData, completed_recipe_ids: Array[String]) -> void:
	if progress == null:
		return
	for construction in all():
		if completed_recipe_ids.has(construction.unlock_recipe_id):
			progress.unlock_construction(construction.id)


func validate() -> PackedStringArray:
	var errors := _load_errors.duplicate()
	for construction in all():
		if construction.unlock_recipe_id.is_empty():
			errors.append("Construcción '%s' sin receta." % construction.id)
		if construction.zone_id.is_empty():
			errors.append("Construcción '%s' sin zona." % construction.id)
		if construction.scene_path.is_empty() or not ResourceLoader.exists(construction.scene_path):
			errors.append("Construcción '%s' con escena inválida '%s'." % [construction.id, construction.scene_path])
		if construction.node_name.is_empty():
			errors.append("Construcción '%s' sin nombre de nodo." % construction.id)
	return errors
