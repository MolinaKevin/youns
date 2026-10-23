extends GutTest

# Partida nueva, guardar y cargar (GameState), con un archivo de prueba para no
# pisar la partida real.

const TEST_PATH := "user://test_player_save.tres"

var _backup := {}


func before_each() -> void:
	_backup = {
		"save": GameState.player_save, "path": GameState.save_path,
		"session": GameState.session_active, "day": GameState.current_day,
		"hour": GameState.time_of_day_hours, "intro": GameState.world_intro_seen,
		"states": StatsManager.active_states.duplicate(true),
		"player_pos": PartyManager.player.global_position,
		"zone": ZoneManager.current_zone,
		"north_trail_open": ZoneManager.north_trail_open,
	}
	GameState.save_path = TEST_PATH
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)


func after_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	GameState.player_save = _backup["save"]
	GameState.save_path = _backup["path"]
	GameState.session_active = _backup["session"]
	GameState.current_day = _backup["day"]
	GameState.time_of_day_hours = _backup["hour"]
	GameState.world_intro_seen = _backup["intro"]
	StatsManager.active_states = _backup["states"]
	StatsManager._emotion_block_count = 0
	GameState.pending_location = {}
	ZoneManager.set_north_trail_open(_backup["north_trail_open"])
	LaboratoryState._pause_current()
	PartyManager.place_at(_backup["player_pos"])


func test_sin_partida_empezada_no_se_guarda_nada() -> void:
	GameState.session_active = false
	GameState.save_player_save()
	assert_false(GameState.has_saved_game())


func test_sin_archivo_no_hay_partida_para_continuar() -> void:
	assert_false(GameState.has_saved_game())
	assert_false(GameState.load_game())


func test_guardar_y_cargar_conserva_la_partida() -> void:
	GameState.start_new_game()
	var ps := GameState.player_save
	ps.gold = 777
	YounStatRules.gain(ps, "fuerza", 25)
	DeckRules.cards(ps)[0].top.intelligence = "musical"
	ps.discovered_evolutions["mboi_tui"] = [1, 3]
	GameState.current_day = 4
	GameState.time_of_day_hours = 15.5
	GameState.world_intro_seen = true
	ZoneManager.set_north_trail_open(true)
	StatsManager.active_states = {"hungry": {"hour": 99.0, "stat_value": 80.0}}
	GameState.save_player_save()
	assert_true(GameState.has_saved_game())

	# Otra partida en memoria (sin guardar), y después se carga la guardada.
	GameState.player_save = PlayerSaveData.new()
	GameState.current_day = 1
	StatsManager.active_states.clear()
	assert_true(GameState.load_game())

	var loaded := GameState.player_save
	assert_eq(loaded.gold, 777)
	assert_eq(YounStatRules.current(loaded, "fuerza"), GameState.STARTING_STATS["fuerza"] + 25)
	assert_eq(loaded.deck[0].top.intelligence, "musical")
	assert_eq(loaded.discovered_evolutions["mboi_tui"], [1, 3])
	assert_eq(GameState.current_day, 4)
	assert_almost_eq(GameState.time_of_day_hours, 15.5, 0.001)
	assert_true(GameState.world_intro_seen)
	assert_true("hungry" in StatsManager.active_states)
	assert_true(GameState.player_save.world_progress.north_trail_open)
	assert_true(ZoneManager.north_trail_open, "el desbloqueo del sendero también se restaura")


func test_partida_nueva_arranca_de_cero() -> void:
	GameState.current_day = 9
	StatsManager.active_states = {"sad": {"hour": 1.0, "stat_value": 0.0}}
	GameState.start_new_game()
	assert_eq(GameState.current_day, 1)
	assert_almost_eq(GameState.time_of_day_hours, 8.0, 0.001)
	assert_true(StatsManager.active_states.is_empty())
	assert_eq(GameState.player_save.current_youn_path, GameState.STARTING_YOUN_PATH)


func test_un_archivo_sin_youn_no_cuenta_como_partida() -> void:
	var junk := PlayerSaveData.new()
	junk.unlocked_recipe_ids = ["advanced"]
	ResourceSaver.save(junk, TEST_PATH)
	assert_false(GameState.has_saved_game())
	assert_false(GameState.load_game())


# ── posición, zona y laboratorio ──────────────────────────────────────────────

func test_se_guarda_donde_esta_el_jugador_y_continuar_lo_deja_listo() -> void:
	GameState.start_new_game()
	PartyManager.place_at(Vector3(12, 1, -7))
	GameState.save_player_save()
	GameState.player_save = PlayerSaveData.new()
	assert_true(GameState.load_game())
	var loc := GameState.pending_location
	assert_eq(loc["zone"], ZoneManager.current_zone)
	assert_almost_eq(loc["position"].x, 12.0, 0.01)
	assert_almost_eq(loc["position"].z, -7.0, 0.01)
	assert_eq(loc["interior"], "")


func test_partida_nueva_aparece_al_inicio() -> void:
	GameState.start_new_game()
	assert_true(GameState.pending_location.get("start", false))


func test_restore_location_pone_al_grupo_en_la_zona_y_posicion() -> void:
	ZoneManager.restore_location("gym", Vector3(10, 1, 60))
	assert_eq(ZoneManager.current_zone, "gym")
	assert_true(ZoneManager.has_loaded_zone("gym"))
	assert_true(ZoneManager.has_loaded_zone("hub"), "las vecinas también quedan cargadas")
	assert_almost_eq(PartyManager.player.global_position.z, 60.0, 0.01)
	ZoneManager.reset_to_start()
	assert_eq(ZoneManager.current_zone, "hub")


func test_la_investigacion_en_curso_sigue_al_cargar() -> void:
	GameState.start_new_game()
	var recipe := LaboratoryState.get_recipe_by_id("producir_datos")
	LaboratoryState.activate_recipe(recipe)
	assert_eq(LaboratoryState.active_recipe_id, "producir_datos")
	LaboratoryState.recipe_progress["producir_datos"] = 0.5
	LaboratoryState._start_recipe(recipe)
	GameState.save_player_save()
	LaboratoryState._pause_current()
	LaboratoryState.recipe_progress.clear()
	GameState.player_save = PlayerSaveData.new()
	assert_true(GameState.load_game())
	assert_eq(LaboratoryState.active_recipe_id, "producir_datos")
	assert_gt(LaboratoryState.get_current_progress("producir_datos"), 0.45)
