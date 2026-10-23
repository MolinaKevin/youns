class_name CareStatsService
extends RefCounted

## Estadísticas fisiológicas y de cuidado. Las emociones y las señales visuales
## se reciben como callbacks para no acoplar este servicio a su presentación.

const STATS_DIR := "res://data/stats/"
const TICKS_PER_HOUR := 3.0
const SLEEP_HEALTH_PER_HOUR := 2
const SLEEP_HEALTH_MAX_HOURS := 8

var _configs: Array[StatConfig] = []
var _accumulators: Dictionary = {}
var _queue_changed: Callable
var _show_emotion: Callable
var _clear_emotion: Callable
var _find_emotion_rule: Callable
var _bathroom_accident: Callable


func _init(queue_changed: Callable, show_emotion: Callable, clear_emotion: Callable, find_rule: Callable, bathroom_accident: Callable) -> void:
	_queue_changed = queue_changed
	_show_emotion = show_emotion
	_clear_emotion = clear_emotion
	_find_emotion_rule = find_rule
	_bathroom_accident = bathroom_accident
	_configs = _load_configs()


func reset() -> void:
	_accumulators.clear()


func calc_hunger_delta(delta: int, multiplier: float, weight: float, base_weight: float) -> int:
	var adjusted := multiplier
	if delta < 0.0 and weight > base_weight:
		adjusted *= maxf(1.0 - (weight - base_weight) * 0.03, 0.3)
	return roundi(delta * adjusted)


func add_stat(key: String, delta: int) -> void:
	var save := GameState.player_save
	if save == null:
		return
	var current = save.get(key)
	if current == null:
		return
	var multiplier := 1.0
	var youn = PartyManager.youn
	var data: YounData = youn.get("youn_data") if youn else null
	if data and data.get("mult_" + key) != null:
		multiplier = data.get("mult_" + key)
	var final_delta := calc_hunger_delta(delta, multiplier, save.weight, data.base_weight) if key == "hambre" and data else roundi(delta * multiplier)
	save.set(key, clampi(int(current) + final_delta, 0, 100))
	_queue_changed.call()


func set_stat(key: String, value: int) -> void:
	var save := GameState.player_save
	if save == null or save.get(key) == null:
		return
	save.set(key, clampi(value, 0, 100))
	_queue_changed.call()


func set_discipline(value: int) -> void:
	if GameState.player_save == null:
		return
	GameState.player_save.discipline = clampi(value, 0, 100)
	GlobalHUD.notify_youns_status_changed()


func add_care_mistake(amount: int = 1) -> void:
	if GameState.player_save == null:
		return
	GameState.player_save.care_mistakes = clampi(GameState.player_save.care_mistakes + amount, 0, 10)
	GlobalHUD.notify_youns_status_changed()


func clear_care_mistakes() -> void:
	if GameState.player_save == null:
		return
	GameState.player_save.care_mistakes = 0
	GlobalHUD.notify_youns_status_changed()


func drain_energy(amount: int) -> void:
	add_stat("energia", -amount)
	_check_sick_chance()


func set_sick(value: bool) -> void:
	if GameState.player_save == null:
		return
	GameState.player_save.enfermo = value
	if value:
		_show_emotion.call("sick")
	else:
		_clear_emotion.call("sick")
	_queue_changed.call()


func set_weight(value: float) -> void:
	if GameState.player_save != null:
		GameState.player_save.weight = maxf(0.0, value)


func on_bathroom_used(rng: RandomNumberGenerator = null) -> void:
	var save := GameState.player_save
	if save == null:
		return
	var random_factor := rng.randf() if rng else randf()
	set_weight(save.weight - save.poop_pending - random_factor * save.weight * 0.1)
	save.poop_pending = 0.0


func attend_bathroom(rng: RandomNumberGenerator = null) -> void:
	if GameState.player_save == null:
		return
	on_bathroom_used(rng)
	set_stat("ganas_bano", 0)
	_clear_emotion.call("bathroom")


func apply_bathroom_accident() -> void:
	if GameState.player_save == null:
		return
	apply_expire_penalty(_find_emotion_rule.call("bathroom"))
	on_bathroom_used()
	set_stat("ganas_bano", 0)
	_clear_emotion.call("bathroom")
	_bathroom_accident.call()


func apply_expire_penalty(rule: EmotionRule) -> void:
	if rule == null:
		return
	for key in rule.expire_stats:
		add_stat(key, rule.expire_stats[key])
	if rule.expire_reset_hambre and GameState.player_save != null:
		GameState.player_save.hambre = 0
	if rule.expire_care_mistakes != 0:
		add_care_mistake(rule.expire_care_mistakes)


func on_meal_eaten() -> void:
	if GameState.player_save == null:
		return
	GameState.player_save.last_meal_total_hour = GameState.get_total_hours()
	_clear_emotion.call("hungry")
	_queue_changed.call()


func apply_decay() -> void:
	var save := GameState.player_save
	if save == null:
		return
	for cfg in _configs:
		if cfg.stat_key.is_empty() or cfg.rate_per_hour == 0.0:
			continue
		var acc: float = _accumulators.get(cfg.stat_key, 0.0) + cfg.rate_per_hour / TICKS_PER_HOUR
		var to_apply := int(acc + signf(acc) * 0.000001)
		_accumulators[cfg.stat_key] = acc - float(to_apply)
		if to_apply != 0 and save.get(cfg.stat_key) != null:
			save.set(cfg.stat_key, clampi(int(save.get(cfg.stat_key)) + to_apply, int(cfg.min_value), int(cfg.max_value)))


func health_from_sleep(hours: int) -> int:
	return clampi(hours, 0, SLEEP_HEALTH_MAX_HOURS) * SLEEP_HEALTH_PER_HOUR


func _check_sick_chance() -> void:
	var save := GameState.player_save
	if save == null or save.enfermo or save.salud >= 80:
		return
	var t := clampf((80.0 - float(save.salud)) / 75.0, 0.0, 1.0)
	var probability := 0.60 * (exp(3.5 * t) - 1.0) / (exp(3.5) - 1.0)
	if randf() < probability:
		set_sick(true)


func _load_configs() -> Array[StatConfig]:
	var result: Array[StatConfig] = []
	var dir := DirAccess.open(STATS_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres"):
			var config = load(STATS_DIR + file)
			if config is StatConfig:
				result.append(config)
		file = dir.get_next()
	return result
