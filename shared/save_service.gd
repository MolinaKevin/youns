class_name SaveService
extends RefCounted

## Ciclo de vida de PlayerSaveData: crear, cargar, migrar, restaurar los
## servicios que persisten estado y escribir la partida al disco.

const SAVE_PATH := "user://player_save.tres"
const CURRENT_SAVE_VERSION := 4
const POMBERO_YOUN_PATH := "res://data/youns/pombero.tres"
const NEWEN_YOUN_PATH := "res://data/youns/newen.tres"
const WorldConstructionCatalogScript := preload("res://data/world/world_construction_catalog.gd")
const CardCatalogScript := preload("res://shared/card_catalog.gd")
const PlayerSaveValidatorScript := preload("res://shared/player_save_validator.gd")
const TypedResourceLoaderScript := preload("res://shared/typed_resource_loader.gd")
const NewGameDefaultsScript := preload("res://data/new_game_defaults.gd")
## Re-exportados para no romper a GameState ni a los tests que ya los usan
## como SaveService.STARTING_*/GameState.STARTING_*; el valor real vive en
## NewGameDefaults, separado del ciclo de vida de guardado.
const STARTING_YOUN_PATH := NewGameDefaultsScript.STARTING_YOUN_PATH
const STARTING_OWNED_CARD_IDS := NewGameDefaultsScript.STARTING_OWNED_CARD_IDS
const STARTING_EQUIPPED_DECK_IDS := NewGameDefaultsScript.STARTING_EQUIPPED_DECK_IDS
const STARTING_ITEM_PATHS := NewGameDefaultsScript.STARTING_ITEM_PATHS
const STARTING_STATS := NewGameDefaultsScript.STARTING_STATS

var save_path := SAVE_PATH
var player_save: PlayerSaveData
var session_active := false
var world_intro_seen := false
var feature_bridge: SaveFeatureBridge


func _init(bridge: SaveFeatureBridge = null) -> void:
	feature_bridge = bridge


func make_new_save(total_hours: float) -> PlayerSaveData:
	var save := PlayerSaveData.new()
	save.save_version = CURRENT_SAVE_VERSION
	save.owned_card_ids = CardCatalogScript.filter_known_ids(STARTING_OWNED_CARD_IDS, "STARTING_OWNED_CARD_IDS")
	save.equipped_deck_ids = CardCatalogScript.filter_known_ids(STARTING_EQUIPPED_DECK_IDS, "STARTING_EQUIPPED_DECK_IDS")
	save.inventory_slots = NewGameDefaultsScript.STARTING_INVENTORY_SLOTS
	for item_path in STARTING_ITEM_PATHS:
		var item := TypedResourceLoaderScript.item(item_path)
		if item != null:
			save.inventory_items.append(item.to_inventory_entry(2))
		else:
			push_error("SaveService: ítem inicial inválido: %s" % item_path)
	save.gold = NewGameDefaultsScript.STARTING_GOLD
	setup_starting_youn(save, total_hours)
	return save


func setup_starting_youn(save: PlayerSaveData, total_hours: float, youn_path := STARTING_YOUN_PATH) -> void:
	var data := TypedResourceLoaderScript.youn(youn_path)
	var resolved_path := youn_path if data != null else STARTING_YOUN_PATH
	if data == null:
		data = TypedResourceLoaderScript.youn(STARTING_YOUN_PATH)
	save.current_youn_path = resolved_path
	save.discovered_evolutions[resolved_path.get_file().get_basename()] = []
	save.youn_stats = data.base_stats.to_dict() if data != null and data.base_stats != null else STARTING_STATS.duplicate()
	save.youn_stat_gains.clear()
	save.stage_entered_total_hour = total_hours


func start_new_session(total_hours: float) -> PlayerSaveData:
	player_save = make_new_save(total_hours)
	world_intro_seen = false
	session_active = true
	restore_feature_state()
	return player_save


func load_from_disk(migrate: bool = true) -> PlayerSaveData:
	if not FileAccess.file_exists(save_path):
		return null
	var loaded := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PlayerSaveData
	if loaded == null or loaded.current_youn_path.is_empty():
		return null
	if is_save_from_future(loaded):
		push_warning("SaveService: la partida fue creada por una versión más nueva del juego y no se cargó.")
		return null
	if migrate:
		migrate_save(loaded)
	for change in PlayerSaveValidatorScript.sanitize(loaded):
		push_warning("SaveService: " + change)
	return loaded


## Lleva una partida guardada al esquema actual. Cada paso debe poder correrse
## más de una vez: evita que una carga repetida altere el progreso.
func migrate_save(save: PlayerSaveData) -> void:
	if save == null:
		return
	if is_save_from_future(save):
		push_warning("SaveService: se evitó migrar una partida de una versión futura (%d > %d)." % [save.save_version, CURRENT_SAVE_VERSION])
		return
	var version := maxi(0, save.save_version)
	while version < CURRENT_SAVE_VERSION:
		match version:
			0:
				_migrate_from_0(save)
			1:
				_migrate_from_1(save)
			2:
				_migrate_from_2(save)
			3:
				_migrate_from_3(save)
		version += 1
	save.save_version = CURRENT_SAVE_VERSION


func is_save_from_future(save: PlayerSaveData) -> bool:
	return save != null and save.save_version > CURRENT_SAVE_VERSION


func _migrate_from_0(save: PlayerSaveData) -> void:
	YounStatRules.migrate_keys(save)
	YounStatRules.ensure_initialized(save)
	if save.world_progress == null:
		save.world_progress = WorldProgressData.new()


func _migrate_from_1(save: PlayerSaveData) -> void:
	if save.world_progress == null:
		save.world_progress = WorldProgressData.new()
	# Antes de que world_bridge persistiera su id, se derivaba de la receta.
	WorldConstructionCatalogScript.new().unlock_completed(save.world_progress, save.completed_recipe_ids)


func _migrate_from_2(save: PlayerSaveData) -> void:
	if save.world_progress == null:
		save.world_progress = WorldProgressData.new()
	save.world_progress.migrate_legacy_bridges()


func _migrate_from_3(save: PlayerSaveData) -> void:
	if save.current_youn_path == POMBERO_YOUN_PATH:
		save.current_youn_path = NEWEN_YOUN_PATH
	if save.pending_evolution_path == POMBERO_YOUN_PATH:
		save.pending_evolution_path = NEWEN_YOUN_PATH
	if save.discovered_evolutions.has("pombero"):
		var discovered: Variant = save.discovered_evolutions["pombero"]
		if not save.discovered_evolutions.has("newen"):
			save.discovered_evolutions["newen"] = discovered
		save.discovered_evolutions.erase("pombero")


func activate_loaded_session(loaded: PlayerSaveData) -> void:
	player_save = loaded
	world_intro_seen = loaded.world_intro_seen
	session_active = true
	restore_feature_state()


func restore_feature_state() -> void:
	if feature_bridge != null:
		feature_bridge.restore(player_save)


## Devuelve OK solo cuando el archivo se escribió correctamente.
func write(day: int, hour: float) -> Error:
	if not session_active or player_save == null:
		return ERR_UNCONFIGURED
	if is_save_from_future(player_save):
		push_warning("SaveService: se evitó sobrescribir una partida de una versión futura.")
		return ERR_INVALID_DATA
	migrate_save(player_save)
	player_save.saved_day = day
	player_save.saved_hour = hour
	player_save.world_intro_seen = world_intro_seen
	if feature_bridge != null:
		feature_bridge.write(player_save)
	return ResourceSaver.save(player_save, save_path)
