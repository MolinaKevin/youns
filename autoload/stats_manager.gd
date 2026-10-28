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

var life_stage: StatsLifeStage
var services: StatsServicesPort

func _ready() -> void:
	var session := CareSessionContext.new(
		func() -> PlayerSaveData: return GameState.player_save,
		func() -> YounData:
			var youn := PartyManager.youn
			return youn.get("youn_data") as YounData if youn else null,
		GameState.get_total_hours,
		GlobalHUD.notify_youns_status_changed,
	)
	care_service = CareStatsService.new(
		session,
		_queue_stat_changed,
		func(emotion_name: String) -> void: emotion_service.show(emotion_name),
		func(emotion_name: String) -> void: emotion_service.clear(emotion_name),
		func(emotion_name: String) -> EmotionRule: return emotion_service.find_rule(emotion_name),
		func() -> void: bathroom_accident.emit(),
	)
	emotion_service = EmotionService.new(
		session,
		care_service.apply_expire_penalty,
		care_service.apply_bathroom_accident,
		_queue_stat_changed,
	)
	life_stage = StatsLifeStage.new(
		func() -> Dictionary: return emotion_service.active_states,
		emotion_service.block,
		emotion_service.unblock,
		care_service.reset,
		_queue_stat_changed,
		emit_evolution_triggered,
		emit_reincarnation_triggered,
	)
	services = StatsServicesAdapter.new(care_service, emotion_service, life_stage)
	GameState.twenty_min_ticked.connect(care_service.apply_decay)
	GameState.twenty_min_ticked.connect(check_status)

# ── Guardado ─────────────────────────────────────────────────────────────────

## Copia los estados activos a la partida (GameState.save_player_save).
func write_to_save(save: PlayerSaveData) -> void:
	emotion_service.write_to_save(save)

## Deja el estado como el de la partida (nueva o cargada).
func restore_from_save(save: PlayerSaveData) -> void:
	emotion_service.restore_from_save(save)
	care_service.reset()
	_queue_stat_changed()

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

# ── check_status ──────────────────────────────────────────────────────────────

func check_status() -> void:
	_sync_sick_emotion()
	if life_stage.check_health_death():
		return
	emotion_service.check_expirations()
	emotion_service.evaluate_rules()
	life_stage.check_evolution()

func _sync_sick_emotion() -> void:
	emotion_service.sync_sick()
