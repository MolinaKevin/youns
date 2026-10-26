extends GutTest

# Reencarnación: fin de la vida, carta heredada y vida nueva del bebé.

const BEBE := "res://data/youns/bebe_1.tres"
const CAMPEON := "res://data/youns/mboi_tui.tres"

var _save_backup: PlayerSaveData
var _day: int
var _hour: float


func before_each() -> void:
	_save_backup = GameState.player_save
	_day = GameState.current_day
	_hour = GameState.time_of_day_hours
	GameState.current_day = 20
	GameState.time_of_day_hours = 10.0
	GameState.player_save = PlayerSaveData.new()
	StatsManager.active_states.clear()
	while StatsManager.emotions_blocked:
		StatsManager.unblock_emotions()


func after_each() -> void:
	GameState.player_save = _save_backup
	GameState.current_day = _day
	GameState.time_of_day_hours = _hour
	StatsManager.active_states.clear()
	while StatsManager.emotions_blocked:
		StatsManager.unblock_emotions()


func _inherited() -> CardData:
	var card: CardData = (load("res://data/cards/diluvio.tres") as CardData).clone()
	DeckRules.recolor(card.top, "naturalista")
	return card


func test_el_campeon_al_terminar_su_vida_empieza_a_morir() -> void:
	var ps := GameState.player_save
	ps.current_youn_path = CAMPEON
	ps.stage_entered_total_hour = GameState.get_total_hours() - 6.5 * 24.0
	watch_signals(StatsManager)
	StatsManager.check_evolution()
	assert_signal_emitted(StatsManager, "reincarnation_triggered")
	assert_true("dying" in StatsManager.active_states)
	assert_true(StatsManager.emotions_blocked)


func test_mientras_muere_no_vuelve_a_dispararse() -> void:
	var ps := GameState.player_save
	ps.current_youn_path = CAMPEON
	ps.stage_entered_total_hour = GameState.get_total_hours() - 6.5 * 24.0
	StatsManager.check_evolution()
	watch_signals(StatsManager)
	StatsManager.check_evolution()
	assert_signal_not_emitted(StatsManager, "reincarnation_triggered")


func test_la_vida_nueva_es_el_bebe_con_su_mazo_y_la_carta_heredada() -> void:
	var ps := GameState.player_save
	ps.current_youn_path = CAMPEON
	ps.gold = 500
	ps.discovered_evolutions = {"mboi_tui": []}
	ps.felicidad = 10
	ps.care_mistakes = 7
	ps.enfermo = true
	var baby: YounData = load(BEBE)
	var inherited := _inherited()
	StatsManager.active_states["dying"] = {"hour": 0.0, "stat_value": 100.0}
	StatsManager.complete_reincarnation(baby, inherited)

	assert_eq(ps.current_youn_path, BEBE)
	assert_eq(YounStatRules.current(ps, "constitucion"), baby.base_stats.constitucion)
	assert_eq(ps.deck.size(), baby.starting_deck.size() + 1)
	var last: CardData = ps.deck[-1]
	assert_eq(last.id, "diluvio")
	assert_eq(last.top.intelligence, "naturalista", "la heredada conserva sus cambios")
	assert_eq(ps.felicidad, baby.base_felicidad)
	assert_eq(ps.care_mistakes, baby.base_care_mistakes)
	assert_false(ps.enfermo)
	assert_almost_eq(ps.stage_entered_total_hour, GameState.get_total_hours(), 0.01)
	assert_false("dying" in StatsManager.active_states)
	assert_false(StatsManager.emotions_blocked)
	# Lo del jugador sigue.
	assert_eq(ps.gold, 500)
	assert_true(ps.discovered_evolutions.has("mboi_tui"))


func test_la_carta_heredada_queda_guardada_para_siempre() -> void:
	var ps := GameState.player_save
	var baby: YounData = load(BEBE)
	StatsManager.complete_reincarnation(baby, _inherited())
	StatsManager.complete_reincarnation(baby, (load("res://data/cards/strike.tres") as CardData).clone())
	assert_eq(ps.saved_cards.size(), 2)
	assert_eq(ps.saved_cards[0].id, "diluvio")
	# Copias propias: no son las mismas que las del mazo.
	assert_ne(ps.saved_cards[1], ps.deck[-1])


func test_en_el_demo_hay_4_huevos_y_solo_uno_se_puede_elegir() -> void:
	assert_eq(ReincarnationRules.EGGS.size(), 4)
	var available := ReincarnationRules.EGGS.filter(func(e): return ReincarnationRules.egg_available(e))
	assert_eq(available.size(), 1)
	assert_eq(available[0]["youn"], BEBE)


func test_el_bebe_tiene_mazo_inicial() -> void:
	var baby: YounData = load(BEBE)
	assert_gt(baby.starting_deck.size(), 0)


func test_la_reencarnacion_desbloquea_el_listado_de_cartas_reencarnadas() -> void:
	var ps := GameState.player_save
	assert_false(ps.reincarnated_cards_unlocked)
	StatsManager.complete_reincarnation(load(BEBE), _inherited())
	assert_true(ps.reincarnated_cards_unlocked)



# ── muerte por salud y vidas ─────────────────────────────────────────────────

func test_con_salud_en_0_el_youn_muere_por_salud() -> void:
	var ps := GameState.player_save
	ps.current_youn_path = "res://data/youns/nguruvilu.tres"
	ps.salud = 0
	watch_signals(StatsManager)
	StatsManager.check_status()
	assert_signal_emitted_with_parameters(StatsManager, "reincarnation_triggered",
		[load("res://data/youns/nguruvilu.tres"), ReincarnationRules.CAUSE_HEALTH])
	assert_eq(StatsManager.active_states["dying"]["cause"], ReincarnationRules.CAUSE_HEALTH)


func test_morir_por_salud_pierde_una_vida_y_no_deja_carta() -> void:
	var ps := GameState.player_save
	ps.current_youn_path = "res://data/youns/nguruvilu.tres"
	ps.salud = 0
	StatsManager.check_status()
	StatsManager.complete_reincarnation(load(BEBE), null)
	assert_eq(ps.lives, ReincarnationRules.MAX_LIVES - 1)
	assert_eq(ps.saved_cards.size(), 0)
	assert_false(ps.reincarnated_cards_unlocked)
	assert_eq(ps.salud, 100)


func test_morir_de_viejo_no_pierde_vidas() -> void:
	var ps := GameState.player_save
	ps.current_youn_path = CAMPEON
	ps.stage_entered_total_hour = GameState.get_total_hours() - 6.5 * 24.0
	StatsManager.check_evolution()
	StatsManager.complete_reincarnation(load(BEBE), _inherited())
	assert_eq(ps.lives, ReincarnationRules.MAX_LIVES)


func test_las_vidas_no_bajan_de_0() -> void:
	var ps := GameState.player_save
	ps.lives = 0
	ps.current_youn_path = "res://data/youns/nguruvilu.tres"
	ps.salud = 0
	StatsManager.check_status()
	StatsManager.complete_reincarnation(load(BEBE), null)
	assert_eq(ps.lives, 0)


# ── la salud en combate ──────────────────────────────────────────────────────

func test_penalidad_por_salud() -> void:
	assert_eq(CardScaling.health_penalty(100), 0.0)
	assert_eq(CardScaling.health_penalty(60), 0.0)
	assert_eq(CardScaling.health_penalty(45), 0.1)
	assert_eq(CardScaling.health_penalty(10), 0.25)


func test_con_poca_salud_las_cartas_rinden_menos() -> void:
	var line := CardActionLine.new()
	line.damage = 100
	line.block_amount = 40
	var full := line.resolved({"health_factor": 1.0})
	var weak := line.resolved({"health_factor": 0.75})
	assert_eq(full.damage, 100)
	assert_eq(weak.damage, 75)
	assert_eq(weak.block_amount, 30)
