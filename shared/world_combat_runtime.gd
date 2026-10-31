class_name WorldCombatRuntime
extends RefCounted

const PlayerSessionAccessScript: GDScript = preload("res://shared/player_session_access.gd")

## Puente de runtime para el inicio de un combate desde el mundo. El Youn no
## conoce autoloads: recibe este contexto y sólo describe el encuentro.

var _context: WorldCombatContext
var _biome: Callable
var _save: Callable
var _bathroom_active: Callable


func _init(context: WorldCombatContext, biome: Callable, save: Callable,
		bathroom_active: Callable) -> void:
	_context = context
	_biome = biome
	_save = save
	_bathroom_active = bathroom_active


static func from_runtime() -> WorldCombatRuntime:
	return WorldCombatRuntime.new(
		GameState.world_combat,
		func() -> BiomeData: return ZoneManager.get_current_biome(),
		func() -> PlayerSaveData: return PlayerSessionAccessScript.save(),
		func() -> bool: return StatsManager.services.emotions().has_state("bathroom"),
	)


func is_active() -> bool:
	return _context.active


func begin(position: Vector3, enemy_id: String, youn_data: YounData) -> void:
	_context.begin(position, enemy_id, youn_data, _biome.call() as BiomeData)
	var player_save := _save.call() as PlayerSaveData
	if player_save != null and _bathroom_active.call():
		player_save.bathroom_pending_after_combat = true
