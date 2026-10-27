extends Node

signal stat_changed
signal bathroom_accident
signal evolution_triggered(from_data: YounData, to_data: YounData)
## El Youn llegó al fin de su vida: empieza la secuencia de muerte y
## reencarnación (game_world). Termina con complete_reincarnation().
signal reincarnation_triggered(from_data: YounData, cause: String)


var _stat_change_pending := false
var emotion_service: EmotionService
var care_service: CareStatsService

var active_states: Dictionary:
	get: return emotion_service.active_states
	set(value): emotion_service.active_states = value

var _life_stage: StatsLifeStage

var emotions_blocked: bool:
	get: return emotion_service.is_blocked()

func _ready() -> void:
	var session := CareSessionContext.new(
		func() -> PlayerSaveData: return GameState.player_save,
		func() -> YounData:
			var youn := PartyManager.youn
			return youn.get("youn_data") as YounData if youn else null,
		GameState.get_total_hours,
		GlobalHUD.notify_youns_status_changed,
	)
	care_service = CareStatsService.new(session, _queue_stat_changed, show_emotion, clear_emotion, _find_emotion_rule, func(): bathroom_accident.emit())
	emotion_service = EmotionService.new(session, care_service.apply_expire_penalty, apply_bathroom_accident, _queue_stat_changed)
	_life_stage = StatsLifeStage.new(
		func() -> Dictionary: return active_states,
		block_emotions,
		unblock_emotions,
		care_service.reset,
		_queue_stat_changed,
		emit_evolution_triggered,
		emit_reincarnation_triggered,
	)
	GameState.twenty_min_ticked.connect(apply_stat_decay)
	GameState.twenty_min_ticked.connect(check_status)

# ── Acceso genérico ───────────────────────────────────────────────────────────

func calc_hambre_delta(delta: int, mult: float, weight: float, base_weight: float) -> int:
	return care_service.calc_hunger_delta(delta, mult, weight, base_weight)


func add_stat(key: String, delta: int) -> void: care_service.add_stat(key, delta)

func set_stat(key: String, value: int) -> void: care_service.set_stat(key, value)

# ── Fachada pública ───────────────────────────────────────────────────────────

## TODO: los consumidores nuevos pueden depender de los servicios internos;
## migrar los existentes de a poco antes de retirar estos wrappers.

# ── Guardado ─────────────────────────────────────────────────────────────────

## Copia los estados activos a la partida (GameState.save_player_save).
func write_to_save(save: PlayerSaveData) -> void:
	emotion_service.write_to_save(save)

## Deja el estado como el de la partida (nueva o cargada).
func restore_from_save(save: PlayerSaveData) -> void:
	emotion_service.restore_from_save(save)
	care_service.reset()
	_queue_stat_changed()

func block_emotions() -> void: emotion_service.block()
func unblock_emotions() -> void: emotion_service.unblock()

func show_emotion(emotion_name: String) -> void: emotion_service.show(emotion_name)

func clear_emotion(emotion_name: String) -> void: emotion_service.clear(emotion_name)

func add_felicidad(delta: int) -> void:    add_stat("felicidad", delta)
func add_confianza(delta: int) -> void:    add_stat("confianza", delta)
func add_estres(delta: int) -> void:       add_stat("estres", delta)
func add_aburrimiento(delta: int) -> void: add_stat("aburrimiento", delta)
func add_autocontrol(delta: int) -> void:  add_stat("autocontrol", delta)
func add_energia(delta: int) -> void:      add_stat("energia", delta)
func add_salud(delta: int) -> void:        add_stat("salud", delta)
func add_hambre(delta: int) -> void:       add_stat("hambre", delta)
func set_ganas_bano(value: int) -> void:   set_stat("ganas_bano", value)

func set_discipline(value: int) -> void:
	care_service.set_discipline(value)

func add_discipline(delta: int) -> void:
	set_discipline(GameState.player_save.discipline + delta)

func add_care_mistake(amount: int = 1) -> void:
	care_service.add_care_mistake(amount)

func clear_care_mistakes() -> void:
	care_service.clear_care_mistakes()

func drain_energia(amount: int) -> void:
	care_service.drain_energy(amount)

func set_enfermo(value: bool) -> void:
	care_service.set_sick(value)

func set_weight(value: float) -> void:
	care_service.set_weight(value)

func add_weight(delta: float) -> void:
	set_weight(GameState.player_save.weight + delta)

func on_bathroom_used(rng: RandomNumberGenerator = null) -> void:
	care_service.on_bathroom_used(rng)


func attend_bathroom(rng: RandomNumberGenerator = null) -> void:
	care_service.attend_bathroom(rng)


func apply_bathroom_accident() -> void:
	care_service.apply_bathroom_accident()

## El Youn comió (ItemEffectMeal): anota la hora y se le va el hambre como
## emoción. Cuánto baja el hambre o suben las ganas de ir al baño lo decide
## cada comida con sus propios efectos.
func on_meal_eaten() -> void:
	care_service.on_meal_eaten()

## Las cuatro interacciones del menú rápido (quick_menu.gd): efecto de
## premiar, castigar, negarle algo o jugar con el Youn.
func reward_youn() -> void: care_service.reward()
func punish_youn() -> void: care_service.punish()
func deny_youn() -> void:   care_service.deny()
func play_with_youn() -> void: care_service.play()

func apply_stat_decay() -> void:
	care_service.apply_decay()

func _queue_stat_changed() -> void:
	if not _stat_change_pending:
		_stat_change_pending = true
		call_deferred("_emit_stat_changed")

func _emit_stat_changed() -> void:
	_stat_change_pending = false
	stat_changed.emit()


## StatsLifeStage decide cuándo ocurren; StatsManager conserva la emisión de
## sus señales públicas para que el analizador y los consumidores la vean acá.
func emit_evolution_triggered(from_data: YounData, to_data: YounData) -> void:
	evolution_triggered.emit(from_data, to_data)


func emit_reincarnation_triggered(from_data: YounData, cause: String) -> void:
	reincarnation_triggered.emit(from_data, cause)

# ── sueño ────────────────────────────────────────────────────────────────────

## Cuánta salud recupera durmiendo `hours` horas.
func salud_from_sleep(hours: int) -> int:
	return care_service.health_from_sleep(hours)

func on_wake_up(sleep_duration_hours: float) -> void:
	emotion_service.on_wake_up(sleep_duration_hours)


# ── check_status ──────────────────────────────────────────────────────────────

func check_status() -> void:
	_sync_sick_emotion()
	if _life_stage.check_health_death():
		return
	check_emotions()
	evaluate_emotion_rules()
	check_evolution()

func check_evolution() -> void:
	_life_stage.check_evolution()

## El Youn muere: por fin de su vida (campeón sin ultimate, o ultimate al
## terminar su tiempo) o por salud en 0 (ReincarnationRules.CAUSE_*).
func start_reincarnation(cause := ReincarnationRules.CAUSE_AGE) -> void:
	_life_stage.start_reincarnation(cause)

## Nace el bebé elegido, con la carta heredada (ver ReincarnationRules). Si
## murió por salud, el jugador pierde una vida.
func complete_reincarnation(baby: YounData, inherited: CardData) -> void:
	_life_stage.complete_reincarnation(baby, inherited)

func start_evolution(to_path: String) -> void:
	_life_stage.start_evolution(to_path)

## Termina la evolución: aplica las stats y agrega la carta característica al
## mazo. Devuelve lo que pasó, para la pantalla de evolución:
## {"from": YounData, "to": YounData, "stat_changes": {"fuerza": 10, ...},
##  "added_card": CardData (la copia que quedó en el mazo) o null,
##  "discovery": condición descubierta (ver EvolutionDiscovery.discover)}.
## Recolorear mitades y agregar líneas lo elige el jugador en esa pantalla.
func complete_evolution() -> Dictionary:
	return _life_stage.complete_evolution()

func check_emotions() -> void:
	emotion_service.check_expirations()

func evaluate_emotion_rules() -> void:
	emotion_service.evaluate_rules()

# El flag enfermo se guarda en la partida pero las emociones no: si el Youn
# está enfermo (al cargar, o después de una evolución que borró todo), vuelve
# a mostrar "sick".
func _sync_sick_emotion() -> void:
	emotion_service.sync_sick()

func _find_emotion_rule(emotion_name: String) -> EmotionRule:
	return emotion_service.find_rule(emotion_name)
