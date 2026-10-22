class_name StatsLifeStage
extends RefCounted

## Dispara evolución/reencarnación cuando corresponde, y resuelve lo que pasa
## cuando se confirman (complete_evolution/complete_reincarnation). Comparte
## `active_states` con el resto de StatsManager (usa "evolving"/"dying" como
## marcas) — `host` es el autoload StatsManager, dueño exclusivo de esta
## instancia. Sin tipo propio porque los autoloads de este proyecto no
## declaran class_name.
var host

func _init(p_host) -> void:
	host = p_host

## Salud en 0: el Youn muere (sin dejar carta) y el jugador pierde una vida.
func check_health_death() -> bool:
	var ps := GameState.player_save
	if ps == null or ps.salud > 0 or ps.current_youn_path.is_empty():
		return false
	if "dying" in host.active_states or "evolving" in host.active_states:
		return true
	start_reincarnation(ReincarnationRules.CAUSE_HEALTH)
	return true

func check_evolution() -> void:
	var ps := GameState.player_save
	if ps == null or ps.current_youn_path.is_empty():
		return
	if not ResourceLoader.exists(ps.current_youn_path):
		return
	# Ya está evolucionando o muriendo.
	if "evolving" in host.active_states or "dying" in host.active_states:
		return
	var youn_data := load(ps.current_youn_path) as YounData
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
	var ps := GameState.player_save
	if ps == null or "dying" in host.active_states:
		return
	var from_data: YounData = null
	if not ps.current_youn_path.is_empty() and ResourceLoader.exists(ps.current_youn_path):
		from_data = load(ps.current_youn_path) as YounData
	host.active_states.clear()
	host.active_states["dying"] = {"hour": GameState.get_total_hours(), "stat_value": 100.0, "cause": cause}
	host.block_emotions()
	host.reincarnation_triggered.emit(from_data, cause)

## Nace el bebé elegido, con la carta heredada (ver ReincarnationRules). Si
## murió por salud, el jugador pierde una vida.
func complete_reincarnation(baby: YounData, inherited: CardData) -> void:
	var ps := GameState.player_save
	if ps == null or baby == null:
		return
	if host.active_states.get("dying", {}).get("cause", "") == ReincarnationRules.CAUSE_HEALTH:
		ps.lives = maxi(0, ps.lives - 1)
	ReincarnationRules.start_new_life(ps, baby, inherited)
	host.active_states.clear()
	host._stat_accumulators.clear()
	host._emotion_block_count = 0
	host._queue_stat_changed()

func start_evolution(to_path: String) -> void:
	var ps := GameState.player_save
	if ps == null or to_path.is_empty():
		return
	var from_data: YounData = null
	if not ps.current_youn_path.is_empty() and ResourceLoader.exists(ps.current_youn_path):
		from_data = load(ps.current_youn_path) as YounData
	var to_data: YounData = null
	if ResourceLoader.exists(to_path):
		to_data = load(to_path) as YounData
	ps.pending_evolution_path = to_path
	host.active_states.clear()
	host.active_states["evolving"] = {
		"hour": GameState.get_total_hours(),
		"stat_value": 100.0,
		"target_youn_path": to_path,
	}
	host.block_emotions()
	host.evolution_triggered.emit(from_data, to_data)

## Termina la evolución: aplica las stats y agrega la carta característica al
## mazo. Devuelve lo que pasó, para la pantalla de evolución:
## {"from": YounData, "to": YounData, "stat_changes": {"fuerza": 10, ...},
##  "added_card": CardData (la copia que quedó en el mazo) o null,
##  "discovery": condición descubierta (ver EvolutionDiscovery.discover)}.
## Recolorear mitades y agregar líneas lo elige el jugador en esa pantalla.
func complete_evolution() -> Dictionary:
	var ps := GameState.player_save
	if ps == null or ps.pending_evolution_path.is_empty():
		return {}
	var from_data: YounData = null
	if not ps.current_youn_path.is_empty() and ResourceLoader.exists(ps.current_youn_path):
		from_data = load(ps.current_youn_path) as YounData
	var to_data: YounData = null
	if ResourceLoader.exists(ps.pending_evolution_path):
		to_data = load(ps.pending_evolution_path) as YounData
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
	host.active_states.erase("evolving")
	host.unblock_emotions()
	return {"from": from_data, "to": to_data, "stat_changes": stat_changes, "added_card": added_card,
		"discovery": discovery}
