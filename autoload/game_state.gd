extends Node

const DebugLogging := preload("res://shared/debug_logging.gd")

signal clock_changed(current_hour: float, current_day: int)
signal twenty_min_ticked

const HOURS_PER_DAY := 24.0
## Un ciclo completo de 24 horas del juego dura veinticuatro minutos reales.
const DAY_DURATION_MINUTES := 24.0
const DAY_DURATION_SECONDS := DAY_DURATION_MINUTES * 60.0

## Dueño del reloj y punto de acceso de transición durante la migración.
var clock: GameClock = GameClock.new()
var save_service: SaveService = SaveService.new()
var player_session: PlayerSessionService

## Compatibilidad temporal: todavía hay consumidores de alto nivel que leen la
## partida desde GameState. Los accesos puntuales nuevos van a SaveService.
var player_save: PlayerSaveData:
	get: return save_service.player_save
	set(value): save_service.player_save = value

var current_day: int:
	get: return clock.current_day
	set(value): clock.current_day = maxi(1, value)

var time_of_day_hours: float:
	get: return clock.time_of_day_hours
	set(value): clock.time_of_day_hours = value

var clock_paused: bool:
	get: return clock.paused
	set(value): clock.set_paused(value)

## Transición efímera mundo → combate → mundo. No forma parte del guardado.
var world_combat: WorldCombatContext = WorldCombatContext.new()
var world_entry: WorldEntryContext = WorldEntryContext.new()
## Evita volver a reproducir la ceremonia al llegar a GameWorld después de la
## escena independiente de una partida nueva.
var new_game_ceremony_completed := false
var ui_return: UiReturnContext = UiReturnContext.new()

## Fachada de los datos iniciales: su dueño es SaveService.
const STARTING_YOUN_PATH := SaveService.STARTING_YOUN_PATH
const STARTING_STATS := SaveService.STARTING_STATS

func _ready() -> void:
	var care_action := func(action: String) -> void:
		match action:
			"reward": StatsManager.reward_youn()
			"punish": StatsManager.punish_youn()
			"deny": StatsManager.deny_youn()
			"play": StatsManager.play_with_youn()
	player_session = PlayerSessionService.new(
		func() -> PlayerSaveData: return player_save,
		care_action,
		GlobalHUD.notify_youns_status_changed,
	)
	save_service.feature_bridge = SaveFeatureBridge.new(
		func(save: PlayerSaveData) -> void:
			StatsManager.restore_from_save(save)
			LaboratoryState.restore_from_save(save),
		func(save: PlayerSaveData) -> void:
			StatsManager.write_to_save(save)
			LaboratoryState.write_to_save(save)
			ZoneManager.write_to_save(save),
	)
	clock.clock_changed.connect(func(hour: float, day: int): clock_changed.emit(hour, day))
	clock.twenty_min_ticked.connect(func(): twenty_min_ticked.emit())
	player_save = save_service.make_new_save(get_total_hours())
	# Permite abrir la escena de combate directamente durante desarrollo.
	world_combat.set_preview_youn(load("res://data/youns/newen.tres") as YounData)
	if DebugLogging.verbose_enabled():
		print("GameState loaded")
	clock_changed.emit(time_of_day_hours, current_day)

func _process(delta: float) -> void:
	advance_real_seconds(delta)

## Registra el Youn inicial (así corre su evolución) y le pone sus stats.
func setup_starting_youn(save: PlayerSaveData) -> void:
	save_service.setup_starting_youn(save, get_total_hours())

func get_time_string() -> String:
	var total_minutes := int(floor(time_of_day_hours * 60.0))
	var hours := int(floor(float(total_minutes) / 60.0)) % 24
	var minutes := total_minutes % 60
	return "%02d:%02d" % [hours, minutes]

func get_time_ratio() -> float:
	return time_of_day_hours / HOURS_PER_DAY

func get_total_hours() -> float:
	return clock.get_total_hours()

## Avanza el reloj usando segundos reales y aplica sus ticks pendientes.
## La usa el loop del juego y permite probar el reloj sin llamar a `_process`.
func advance_real_seconds(seconds: float) -> void:
	clock.advance_real_seconds(seconds, DAY_DURATION_SECONDS)

## Descarta los twenty_min_ticked pendientes: el tiempo que se salteó (p. ej.
## durmiendo) no aplica desgaste de stats ni chequeos de emociones.
func discard_pending_ticks() -> void:
	clock.discard_pending_ticks()

## Adelanta el reloj y emite en esta llamada los ticks de veinte minutos que
## correspondan, así hambre y emociones se ponen al día de inmediato.
func advance_hours(hours: float) -> void:
	clock.advance_hours(hours)

## Salto de tiempo sin desgaste acumulado, pensado para dormir.
func skip_hours(hours: float, notify: bool = true) -> void:
	clock.skip_hours(hours, notify)

func skip_to_next_hour(hour: int, notify: bool = true) -> int:
	return clock.skip_to_next_hour(hour, notify)

## Fija una fecha cargada o preparada por un test, sin ticks pendientes.
func set_clock(day: int, hour: float) -> void:
	clock.set_time(day, hour)

func set_clock_paused(paused: bool) -> void:
	clock.set_paused(paused)

func notify_clock_changed() -> void:
	clock.notify_clock_changed()

# ── Partida: nueva, cargar, guardar ──────────────────────────────────────────

## Hay una partida guardada que se puede continuar.
func has_saved_game() -> bool:
	return save_service.load_from_disk(false) != null

## Empieza una partida nueva desde el menú (la guardada se pisa recién al
## guardar la nueva).
func start_new_game() -> void:
	# La etapa inicial del Youn se guarda con la hora real de esta partida, no
	# con la hora de la sesión anterior.
	new_game_ceremony_completed = false
	clock.set_time(1, 8.0, false)
	_reset_session()
	save_service.start_new_session(get_total_hours())
	world_entry.request_start()

## Carga la partida guardada. false si no hay o no se pudo leer.
func load_game() -> bool:
	var loaded := save_service.load_from_disk()
	if loaded == null:
		return false
	clock.set_time(loaded.saved_day, loaded.saved_hour, false)
	_reset_session()
	save_service.activate_loaded_session(loaded)
	ZoneManager.set_north_trail_open(loaded.world_progress.north_trail_open)
	if loaded.has_saved_position:
		world_entry.request_restore(loaded.saved_zone, loaded.saved_position, loaded.saved_interior)
	else:
		world_entry.request_start()
	notify_clock_changed()
	return true

## Guarda la partida con el estado del momento (reloj, estados, laboratorio).
## Solo se llama al dormir (si el jugador elige guardar) y en las estaciones de
## guardado. No hace nada hasta que se empieza o carga una partida desde el menú.
func save_player_save() -> Error:
	return save_service.write(current_day, time_of_day_hours)

func _reset_session() -> void:
	world_combat.clear()
	discard_pending_ticks()
