class_name StatsLifeStage
extends RefCounted

const TypedResourceLoaderScript := preload("res://shared/typed_resource_loader.gd")

## Dispara evolución/reencarnación cuando corresponde, y resuelve lo que pasa
## cuando se confirman (complete_evolution/complete_reincarnation). Comparte
## `active_states` con EmotionService (usa "evolving"/"dying" como marcas).
## Sus efectos colaterales llegan por callbacks, no por los internals del
## autoload que lo compone.
var _get_save: Callable
var _emotions: EmotionService
var _reset_care: Callable
var _queue_stat_changed: Callable
var _evolution_triggered: Callable
var _reincarnation_triggered: Callable

func _init(get_save: Callable, emotions: EmotionService, reset_care: Callable, queue_stat_changed: Callable, evolution_triggered: Callable, reincarnation_triggered: Callable) -> void:
	_get_save = get_save
	_emotions = emotions
	_reset_care = reset_care
	_queue_stat_changed = queue_stat_changed
	_evolution_triggered = evolution_triggered
	_reincarnation_triggered = reincarnation_triggered

## Salud en 0: el Youn muere (sin dejar carta) y el jugador pierde una vida.
func check_health_death() -> bool:
	var ps := _get_save.call() as PlayerSaveData
	if ps == null or ps.salud > 0 or ps.current_youn_path.is_empty():
		return false
	if _emotions.transition_active():
		return true
	start_reincarnation(ReincarnationRules.CAUSE_HEALTH)
	return true

func check_evolution() -> void:
	var ps := _get_save.call() as PlayerSaveData
	if ps == null or ps.current_youn_path.is_empty():
		return
	var youn_data := TypedResourceLoaderScript.youn(ps.current_youn_path)
	if youn_data == null:
		return
	# Ya está evolucionando o muriendo.
	if _emotions.transition_active():
		return
	var target := EvolutionChecker.try_evolve(ps, youn_data)
	if target.is_empty():
		return
	if target == EvolutionChecker.REINCARNATE:
		start_reincarnation()
		return
	start_evolution(target)

## El Youn muere: por fin de su vida (campeón sin ultimate, o ultimate al
## terminar su tiempo) o por salud en 0 (ReincarnationRules.CAUSE_*).
func start_reincarnation(cause := ReincarnationRules.CAUSE_AGE) -> void:
	var ps := _get_save.call() as PlayerSaveData
	if ps == null or _emotions.transition_active():
		return
	var from_data: YounData = null
	if not ps.current_youn_path.is_empty():
		from_data = TypedResourceLoaderScript.youn(ps.current_youn_path)
	_emotions.begin_reincarnation(cause)
	_reincarnation_triggered.call(from_data, cause)

## Nace el bebé elegido, con la carta heredada (ver ReincarnationRules). Si
## murió por salud, el jugador pierde una vida.
func complete_reincarnation(baby: YounData, inherited: CardData) -> void:
	var ps := _get_save.call() as PlayerSaveData
	if ps == null or baby == null:
		return
	if _emotions.transition_entry("dying").get("cause", "") == ReincarnationRules.CAUSE_HEALTH:
		ps.lives = maxi(0, ps.lives - 1)
	ReincarnationRules.start_new_life(ps, baby, inherited)
	_emotions.finish_transition("dying", true)
	_reset_care.call()
	# Termina cualquier bloqueo que dejó la muerte; una vida nueva no hereda
	# transiciones pendientes.
	_queue_stat_changed.call()

func start_evolution(to_path: String) -> void:
	var ps := _get_save.call() as PlayerSaveData
	if ps == null or to_path.is_empty():
		return
	var from_data: YounData = null
	if not ps.current_youn_path.is_empty():
		from_data = TypedResourceLoaderScript.youn(ps.current_youn_path)
	var to_data := TypedResourceLoaderScript.youn(to_path)
	ps.pending_evolution_path = to_path
	_emotions.begin_evolution(to_path)
	_evolution_triggered.call(from_data, to_data)

## Termina la evolución: aplica las stats y agrega la carta característica al
## mazo. Devuelve lo que pasó, para la pantalla de evolución:
## {"from": YounData, "to": YounData, "stat_changes": {"fuerza": 10, ...},
##  "added_card": CardData (la copia que quedó en el mazo) o null,
##  "discovery": condición descubierta (ver EvolutionDiscovery.discover)}.
## Recolorear mitades y agregar líneas lo elige el jugador en esa pantalla.
func complete_evolution() -> Dictionary:
	var ps := _get_save.call() as PlayerSaveData
	if ps == null or ps.pending_evolution_path.is_empty():
		return {}
	var from_data: YounData = null
	if not ps.current_youn_path.is_empty():
		from_data = TypedResourceLoaderScript.youn(ps.current_youn_path)
	var to_data := TypedResourceLoaderScript.youn(ps.pending_evolution_path)
	var stats_before := ps.youn_stats.duplicate()
	# Qué condiciones se cumplieron (con el Youn y las stats de antes de evolucionar).
	var met := EvolutionDiscovery.met_indices(to_data, EvolutionChecker.make_context(ps, from_data))
	var discovery := EvolutionDiscovery.discover(ps, to_data, met)
	ps.current_youn_path = ps.pending_evolution_path
	if to_data != null:
		YounStatRules.apply_evolution(ps, to_data)
	var stat_changes := {}
	for key in YounStats.KEYS:
		var delta := int(ps.youn_stats.get(key, 0)) - int(stats_before.get(key, 0))
		if delta != 0:
			stat_changes[key] = delta
	var added_card: CardData = null
	if to_data != null and to_data.signature_card != null:
		added_card = DeckRules.add_card(ps, to_data.signature_card)
	ps.stage_entered_total_hour = GameState.get_total_hours()
	ps.pending_evolution_path = ""
	_emotions.finish_transition("evolving")
	return {"from": from_data, "to": to_data, "stat_changes": stat_changes, "added_card": added_card,
		"discovery": discovery}
