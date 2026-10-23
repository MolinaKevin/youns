class_name EmotionService
extends RefCounted

## Reglas y ciclo de vida de emociones. Recibe callbacks para las consecuencias
## de cuidado (penalidades y accidente) sin poseer las stats ni las cinemáticas.

const RULES_DIR := "res://data/emotions/rules/"

var active_states: Dictionary = {}
var _rules: Array[EmotionRule] = []
var _block_count := 0
var _apply_expire_penalty: Callable
var _apply_bathroom_accident: Callable
var _queue_stat_changed: Callable


func _init(expire_penalty: Callable, bathroom_accident: Callable, stat_changed: Callable) -> void:
	_apply_expire_penalty = expire_penalty
	_apply_bathroom_accident = bathroom_accident
	_queue_stat_changed = stat_changed
	_rules = _load_rules()


func is_blocked() -> bool:
	return _block_count > 0


func block() -> void:
	_block_count += 1


func unblock() -> void:
	_block_count = maxi(0, _block_count - 1)


func write_to_save(save: PlayerSaveData) -> void:
	save.active_states = active_states.duplicate(true)


func restore_from_save(save: PlayerSaveData) -> void:
	active_states = save.active_states.duplicate(true) if save != null else {}
	_block_count = 1 if ("evolving" in active_states or "dying" in active_states) else 0


func show(emotion_name: String) -> void:
	if is_blocked() or emotion_name.is_empty():
		return
	if emotion_name == "sick" and GameState.player_save and not GameState.player_save.enfermo:
		GameState.player_save.enfermo = true
		_queue_stat_changed.call()
	if emotion_name in active_states:
		return
	var rule := find_rule(emotion_name)
	var stat_value := 100.0
	if rule and not rule.stat_key.is_empty() and GameState.player_save:
		var raw = GameState.player_save.get(rule.stat_key)
		if raw != null:
			stat_value = float(raw)
	active_states[emotion_name] = {"hour": GameState.get_total_hours(), "stat_value": stat_value}


func clear(emotion_name: String) -> void:
	active_states.erase(emotion_name)


func check_expirations() -> void:
	var total_h := GameState.get_total_hours()
	for emotion_name in active_states.keys():
		var rule := find_rule(emotion_name)
		if rule == null or rule.max_duration_hours <= 0.0:
			continue
		var since_hour: float = active_states[emotion_name].get("hour", 0.0)
		if total_h - since_hour < rule.max_duration_hours:
			continue
		if emotion_name == "bathroom":
			_apply_bathroom_accident.call()
			continue
		_apply_expire_penalty.call(rule)
		clear(emotion_name)


func evaluate_rules() -> void:
	var ps := GameState.player_save
	if ps == null or _rules.is_empty() or is_blocked():
		return
	var youn = PartyManager.youn
	var ctx := {"save": ps, "youn_data": youn.get("youn_data") if youn else null, "active": active_states.keys()}
	for emotion_name in EmotionEngine.evaluate(_rules, ctx):
		show(emotion_name)
	for emotion_name in active_states.keys():
		if emotion_name == "sick":
			continue
		var rule := find_rule(emotion_name)
		if rule == null:
			continue
		if rule is EmotionRuleTimeWindow:
			if ctx["youn_data"] != null and rule.evaluate(ctx) <= 0.0:
				clear(emotion_name)
			continue
		if rule.stat_key.is_empty():
			continue
		var current_val = ps.get(rule.stat_key)
		if current_val != null and rule.improved_since(float(active_states[emotion_name].get("stat_value", 100.0)), float(current_val)) and randf() >= rule.evaluate(ctx):
			clear(emotion_name)


func sync_sick() -> void:
	var ps := GameState.player_save
	if ps != null and ps.enfermo and "sick" not in active_states:
		show("sick")


func on_wake_up(sleep_duration_hours: float) -> void:
	clear("tired")
	clear("sleep")
	var bathroom_rule := find_rule("bathroom")
	if "bathroom" in active_states and bathroom_rule:
		var elapsed := GameState.get_total_hours() - float(active_states["bathroom"].get("hour", 0.0))
		if elapsed >= bathroom_rule.max_duration_hours * 0.5:
			_apply_bathroom_accident.call()
		else:
			active_states["bathroom"]["hour"] += sleep_duration_hours
	for emotion_name in active_states.keys():
		if emotion_name != "bathroom":
			active_states[emotion_name]["hour"] += sleep_duration_hours


func find_rule(emotion_name: String) -> EmotionRule:
	for rule in _rules:
		if rule.emotion_name == emotion_name:
			return rule
	return null


func _load_rules() -> Array[EmotionRule]:
	var result: Array[EmotionRule] = []
	var dir := DirAccess.open(RULES_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres"):
			var rule = load(RULES_DIR + file)
			if rule is EmotionRule:
				result.append(rule)
		file = dir.get_next()
	return result
