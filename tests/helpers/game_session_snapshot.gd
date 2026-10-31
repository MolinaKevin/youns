class_name GameSessionSnapshot
extends RefCounted

## Snapshot mínimo de autoloads mutados por pruebas de integración. Mantiene el
## aislamiento sin que cada archivo tenga que conocer los detalles de GameState,
## StatsManager, PartyManager y ZoneManager.

var _save: PlayerSaveData
var _save_path: String
var _session_active: bool
var _day: int
var _hour: float
var _world_intro_seen: bool
var _emotion_states: Dictionary
var _player_position: Vector3
var _north_trail_open: bool


static func capture() -> GameSessionSnapshot:
	var snapshot := GameSessionSnapshot.new()
	snapshot._save = GameState.save_service.player_save
	snapshot._save_path = GameState.save_service.save_path
	snapshot._session_active = GameState.save_service.session_active
	snapshot._day = GameState.current_day
	snapshot._hour = GameState.time_of_day_hours
	snapshot._world_intro_seen = GameState.save_service.world_intro_seen
	snapshot._emotion_states = StatsManager.emotion_service.active_states.duplicate(true)
	snapshot._player_position = PartyManager.player.global_position if is_instance_valid(PartyManager.player) else Vector3.ZERO
	snapshot._north_trail_open = ZoneManager.north_trail_open
	return snapshot


func restore() -> void:
	GameState.save_service.player_save = _save
	GameState.save_service.save_path = _save_path
	GameState.save_service.session_active = _session_active
	GameState.current_day = _day
	GameState.time_of_day_hours = _hour
	GameState.save_service.world_intro_seen = _world_intro_seen
	StatsManager.emotion_service.active_states = _emotion_states
	while StatsManager.emotion_service.is_blocked():
		StatsManager.emotion_service.unblock()
	GameState.world_entry.clear()
	ZoneManager.set_north_trail_open(_north_trail_open)
	LaboratoryState.pause_active_recipe()
	if is_instance_valid(PartyManager.player):
		PartyManager.place_at(_player_position)
