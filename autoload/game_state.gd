extends Node

signal clock_changed(current_hour: float, current_day: int)
signal twenty_min_ticked

const HOURS_PER_DAY := 24.0
const DAY_DURATION_MINUTES := 12.0
const DAY_DURATION_SECONDS := DAY_DURATION_MINUTES * 60.0

const SAVE_PATH := "user://player_save.tres"
## Archivo de la partida (los tests usan otro para no pisar la real).
var save_path := SAVE_PATH
const RUN_PATH := "user://current_run.tres"

var test_mode := true

var player_save: PlayerSaveData
var current_run: RunStateData
var pending_wild_youn_data
var combat_return_pending := false
var combat_return_position := Vector3.ZERO
var combat_world_enemy_id := ""
var world_intro_seen := false
var ui_return_scene_path := ""
var current_day := 1
var time_of_day_hours := 8.0
var clock_paused := false

var _last_total_twenty_min_tick: int = 0

## PROVISORIO: toda partida nueva arranca con este Youn rookie y estas stats
## fijas. En el juego final un diálogo inicial va a elegir entre 2 Youns según
## lo que responda el jugador (docs/TODO.md).
const STARTING_YOUN_PATH := "res://data/youns/nguruvilu.tres"
const STARTING_STATS := {
	"constitucion": 55, "mente": 45, "fuerza": 50, "resistencia": 50,
	"agilidad": 45, "tecnica": 45, "inteligencia": 45, "espiritu": 60,
}

## Si hay una partida en juego (nueva o cargada desde el menú). Antes de eso la
## partida es la de prueba del arranque y no se guarda: si no, pisaría la
## partida guardada cada vez que se abre el juego.
var session_active := false
## Dónde tiene que aparecer el jugador al entrar al mundo después de "Nueva
## partida" o "Continuar" (lo aplica game_world). Vacío = no tocar.
var pending_location: Dictionary = {}

func _ready() -> void:
	player_save = _make_new_save()
	pending_wild_youn_data = load("res://data/youns/pombero.tres")
	_last_total_twenty_min_tick = int(get_total_hours() * 3.0)
	print("GameState loaded")
	clock_changed.emit(time_of_day_hours, current_day)

## Partida nueva (PROVISORIO: con el mazo, los ítems y el Youn de prueba).
func _make_new_save() -> PlayerSaveData:
	var save := PlayerSaveData.new()
	save.owned_card_ids = ["step", "dash", "strike", "slash", "block", "barrera", "meditar", "golpe_escudo", "represalia", "tiron", "ancla", "demoler", "carga_explosiva", "muro", "golpe_de_roca", "muro_arcano", "derrumbe", "lanzar_roca", "chispa", "escarcha", "descarga", "aliento", "nova", "ceguera", "lentitud", "raices", "curar", "encantar_arma", "parpadeo", "traslado_charco", "granizada", "diluvio", "lluvia_acida", "trepar", "meteor", "arrow", "snipe", "grenade", "salto_rupestre", "envion", "charco", "charco_fuego", "charco_grasa", "enredadera", "charco_sangre", "charco_veneno", "charco_arena", "emboscada"]
	save.equipped_deck_ids = [
		"step", "step", "step",
		"dash", "dash",
		"strike", "strike", "strike",
		"slash", "slash",
		"block", "block", "block",
		"barrera", "barrera",
		"meditar", "meditar",
		"golpe_escudo", "golpe_escudo",
		"represalia", "represalia",
		"tiron", "tiron",
		"ancla", "ancla",
		"demoler", "carga_explosiva",
		"muro", "muro",
		"golpe_de_roca", "golpe_de_roca",
		"muro_arcano", "muro_arcano",
		"derrumbe", "derrumbe",
		"lanzar_roca", "lanzar_roca",
		"chispa",
		"escarcha",
		"descarga",
		"aliento",
		"nova",
		"ceguera",
		"lentitud",
		"raices",
		"curar",
		"encantar_arma",
		"parpadeo",
		"traslado_charco", "traslado_charco",
		"granizada", "diluvio", "lluvia_acida",
		"trepar", "trepar",
		"meteor", "meteor",
		"arrow", "arrow", "arrow",
		"snipe", "snipe",
		"grenade", "grenade",
		"bear_trap", "bear_trap",
		"spike_trap", "spike_trap",
		"salto_rupestre", "salto_rupestre",
		"envion", "envion",
		"charco", "charco",
		"charco_fuego", "charco_grasa",
		"enredadera", "charco_sangre",
		"charco_veneno", "charco_arena",
		"emboscada", "emboscada",
	]
	save.inventory_slots = 20
	save.inventory_items = []
	# PROVISORIO para testear el comodín "Ítem" del combate.
	for item_path in ["res://data/items/hierba_curativa.tres", "res://data/items/agua_de_manantial.tres", "res://data/items/unguento.tres"]:
		save.inventory_items.append((load(item_path) as ItemData).to_inventory_entry(2))
	save.gold = 100
	setup_starting_youn(save)
	return save

func _process(delta: float) -> void:
	if clock_paused:
		return
	time_of_day_hours += delta * HOURS_PER_DAY / DAY_DURATION_SECONDS
	while time_of_day_hours >= HOURS_PER_DAY:
		time_of_day_hours -= HOURS_PER_DAY
		current_day += 1
	clock_changed.emit(time_of_day_hours, current_day)
	var current_twenty_tick := int(get_total_hours() * 3.0)
	while _last_total_twenty_min_tick < current_twenty_tick:
		_last_total_twenty_min_tick += 1
		twenty_min_ticked.emit()

## Registra el Youn inicial (así corre su evolución) y le pone sus stats.
func setup_starting_youn(save: PlayerSaveData) -> void:
	save.current_youn_path = STARTING_YOUN_PATH
	# Aparece en el árbol de evoluciones desde el principio.
	save.discovered_evolutions[STARTING_YOUN_PATH.get_file().get_basename()] = []
	save.youn_stats = STARTING_STATS.duplicate()
	save.youn_stat_gains.clear()
	save.stage_entered_total_hour = get_total_hours()

func get_time_string() -> String:
	var total_minutes := int(floor(time_of_day_hours * 60.0))
	var hours := int(floor(float(total_minutes) / 60.0)) % 24
	var minutes := total_minutes % 60
	return "%02d:%02d" % [hours, minutes]

func get_time_ratio() -> float:
	return time_of_day_hours / HOURS_PER_DAY

func get_total_hours() -> float:
	return current_day * 24.0 + time_of_day_hours

## Descarta los twenty_min_ticked pendientes: el tiempo que se salteó (p. ej.
## durmiendo) no aplica desgaste de stats ni chequeos de emociones.
func discard_pending_ticks() -> void:
	_last_total_twenty_min_tick = int(get_total_hours() * 3.0)

## Adelanta el reloj. Los twenty_min_ticked salteados se emiten en el próximo
## _process (con el reloj andando), así el hambre y demás se ponen al día.
func advance_hours(hours: float) -> void:
	time_of_day_hours += hours
	while time_of_day_hours >= HOURS_PER_DAY:
		time_of_day_hours -= HOURS_PER_DAY
		current_day += 1
	clock_changed.emit(time_of_day_hours, current_day)

# ── Partida: nueva, cargar, guardar ──────────────────────────────────────────

## Hay una partida guardada que se puede continuar.
func has_saved_game() -> bool:
	return _read_save() != null

## La partida del archivo, o null si no hay o no es una partida válida (p. ej.
## un archivo viejo sin Youn registrado).
func _read_save() -> PlayerSaveData:
	if not FileAccess.file_exists(save_path):
		return null
	# Sin caché: siempre lo que está en disco, no una partida vieja en memoria.
	var loaded := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PlayerSaveData
	if loaded == null or loaded.current_youn_path.is_empty():
		return null
	return loaded

## Empieza una partida nueva desde el menú (la guardada se pisa recién al
## guardar la nueva).
func start_new_game() -> void:
	player_save = _make_new_save()
	current_day = 1
	time_of_day_hours = 8.0
	world_intro_seen = false
	_reset_session()
	session_active = true
	pending_location = {"start": true}
	StatsManager.restore_from_save(player_save)
	LaboratoryState.restore_from_save(player_save)

## Carga la partida guardada. false si no hay o no se pudo leer.
func load_game() -> bool:
	var loaded := _read_save()
	if loaded == null:
		return false
	player_save = loaded
	YounStatRules.migrate_keys(player_save)
	YounStatRules.ensure_initialized(player_save)
	current_day = player_save.saved_day
	time_of_day_hours = player_save.saved_hour
	world_intro_seen = player_save.world_intro_seen
	_reset_session()
	session_active = true
	if player_save.has_saved_position:
		pending_location = {"zone": player_save.saved_zone, "position": player_save.saved_position,
			"interior": player_save.saved_interior}
	else:
		pending_location = {"start": true}
	StatsManager.restore_from_save(player_save)
	LaboratoryState.restore_from_save(player_save)
	clock_changed.emit(time_of_day_hours, current_day)
	return true

## Guarda la partida con el estado del momento (reloj, estados, laboratorio).
## Solo se llama al dormir (si el jugador elige guardar) y en las estaciones de
## guardado. No hace nada hasta que se empieza o carga una partida desde el menú.
func save_player_save() -> void:
	if not session_active or player_save == null:
		return
	player_save.saved_day = current_day
	player_save.saved_hour = time_of_day_hours
	player_save.world_intro_seen = world_intro_seen
	StatsManager.write_to_save(player_save)
	LaboratoryState.write_to_save(player_save)
	ZoneManager.write_to_save(player_save)
	ResourceSaver.save(player_save, save_path)

func _reset_session() -> void:
	combat_return_pending = false
	combat_world_enemy_id = ""
	discard_pending_ticks()

func load_run_state() -> void:
	if ResourceLoader.exists(RUN_PATH):
		current_run = ResourceLoader.load(RUN_PATH)
	else:
		current_run = RunStateData.new()

func save_run_state() -> void:
	ResourceSaver.save(current_run, RUN_PATH)

func reset_run_state() -> void:
	current_run = RunStateData.new()
	save_run_state()
