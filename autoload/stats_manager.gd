extends Node

signal stat_changed
signal bathroom_accident

const STATS_DIR := "res://data/stats/"
const RULES_DIR := "res://data/emotions/rules/"

var _stat_configs: Array[StatConfig] = []
var _emotion_rules: Array[EmotionRule] = []
var _stat_accumulators: Dictionary = {}
var _emotion_block_count: int = 0
var _stat_change_pending := false

## Mapa de estados activos: emotion_name -> total_hour en que apareció
var active_states: Dictionary = {}

var emotions_blocked: bool:
	get: return _emotion_block_count > 0

func _ready() -> void:
	_stat_configs = _load_stat_configs()
	_emotion_rules = _load_emotion_rules()
	GameState.twenty_min_ticked.connect(apply_stat_decay)
	GameState.twenty_min_ticked.connect(check_status)

# ── Acceso genérico ───────────────────────────────────────────────────────────

func add_stat(key: String, delta: int) -> void:
	if GameState.player_save == null:
		return
	var current = GameState.player_save.get(key)
	if current == null:
		return
	var multiplier := 1.0
	var youn = PartyManager.youn
	var youn_data: YounData = youn.get("youn_data") if youn else null
	if youn_data:
		var val = youn_data.get("mult_" + key)
		if val != null:
			multiplier = val
		if key == "hambre" and delta < 0:
			var kg_over := GameState.player_save.weight - youn_data.base_weight
			if kg_over > 0.0:
				multiplier *= maxf(1.0 - kg_over * 0.03, 0.3)
	GameState.player_save.set(key, clampi(int(current) + roundi(delta * multiplier), 0, 100))
	_queue_stat_changed()

func set_stat(key: String, value: int) -> void:
	if GameState.player_save == null:
		return
	if GameState.player_save.get(key) == null:
		return
	GameState.player_save.set(key, clampi(value, 0, 100))
	_queue_stat_changed()

# ── Wrappers nombrados ────────────────────────────────────────────────────────

func block_emotions() -> void:   _emotion_block_count += 1
func unblock_emotions() -> void: _emotion_block_count = maxi(0, _emotion_block_count - 1)

func show_emotion(emotion_name: String) -> void:
	if _emotion_block_count > 0 or emotion_name.is_empty():
		return
	if emotion_name not in active_states:
		var rule := _find_emotion_rule(emotion_name)
		var stat_value := 100.0
		if rule and not rule.stat_key.is_empty() and GameState.player_save:
			var raw = GameState.player_save.get(rule.stat_key)
			if raw != null:
				stat_value = float(raw)
		active_states[emotion_name] = {
			"hour": GameState.get_total_hours(),
			"stat_value": stat_value,
		}

func clear_emotion(emotion_name: String) -> void:
	active_states.erase(emotion_name)

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
	if GameState.player_save == null:
		return
	GameState.player_save.discipline = clampi(value, 0, 100)
	GlobalHUD.notify_youns_status_changed()

func add_discipline(delta: int) -> void:
	set_discipline(GameState.player_save.discipline + delta)

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

func drain_energia(amount: int) -> void:
	add_energia(-amount)
	_check_sick_chance()

func _check_sick_chance() -> void:
	if GameState.player_save == null or GameState.player_save.enfermo:
		return
	var salud := GameState.player_save.salud
	if salud >= 80:
		return
	var t := clampf((80.0 - float(salud)) / 75.0, 0.0, 1.0)
	const K := 3.5
	var prob := 0.60 * (exp(K * t) - 1.0) / (exp(K) - 1.0)
	if randf() < prob:
		set_enfermo(true)

func set_enfermo(value: bool) -> void:
	if GameState.player_save == null:
		return
	GameState.player_save.enfermo = value
	if not value:
		clear_emotion("sick")
	_queue_stat_changed()

func set_weight(value: float) -> void:
	if GameState.player_save == null:
		return
	GameState.player_save.weight = maxf(0.0, value)

func add_weight(delta: float) -> void:
	set_weight(GameState.player_save.weight + delta)

func apply_bathroom_accident() -> void:
	var ps := GameState.player_save
	if ps == null:
		return
	var rule := _find_emotion_rule("bathroom")
	_apply_expire_penalty(rule)
	set_ganas_bano(0)
	clear_emotion("bathroom")
	bathroom_accident.emit()

func _apply_expire_penalty(rule: EmotionRule) -> void:
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
	var ps := GameState.player_save
	ps.hambre = 0
	ps.last_meal_total_hour = GameState.get_total_hours()
	ps.ganas_bano = mini(ps.ganas_bano + 25, 100)
	clear_emotion("hungry")
	_queue_stat_changed()

# ── Tick por media hora ───────────────────────────────────────────────────────

func apply_stat_decay() -> void:
	if GameState.player_save == null:
		return
	for cfg: StatConfig in _stat_configs:
		if cfg.stat_key.is_empty() or cfg.rate_per_hour == 0.0:
			continue
		var acc: float = _stat_accumulators.get(cfg.stat_key, 0.0) + cfg.rate_per_hour * 0.5
		var to_apply := int(acc)
		_stat_accumulators[cfg.stat_key] = acc - float(to_apply)
		if to_apply == 0:
			continue
		var current = GameState.player_save.get(cfg.stat_key)
		if current == null:
			continue
		GameState.player_save.set(cfg.stat_key, clampi(int(current) + to_apply, int(cfg.min_value), int(cfg.max_value)))

func _queue_stat_changed() -> void:
	if not _stat_change_pending:
		_stat_change_pending = true
		call_deferred("_emit_stat_changed")

func _emit_stat_changed() -> void:
	_stat_change_pending = false
	stat_changed.emit()

# ── check_status ──────────────────────────────────────────────────────────────

func check_status() -> void:
	check_emotions()
	_evaluate_emotion_rules()

func check_emotions() -> void:
	var total_h := GameState.get_total_hours()
	for emotion_name in active_states.keys():
		var rule := _find_emotion_rule(emotion_name)
		if rule == null or rule.max_duration_hours <= 0.0:
			continue
		var since_hour: float = active_states[emotion_name].get("hour", 0.0)
		if total_h - since_hour >= rule.max_duration_hours:
			_apply_expire_penalty(rule)
			clear_emotion(emotion_name)
			if emotion_name == "bathroom":
				bathroom_accident.emit()

func _evaluate_emotion_rules() -> void:
	var ps := GameState.player_save
	if ps == null or _emotion_rules.is_empty() or emotions_blocked:
		return
	var youn = PartyManager.youn
	var ctx := {
		"save": ps,
		"youn_data": youn.get("youn_data") if youn else null,
	}
	var triggered := EmotionEngine.evaluate(_emotion_rules, ctx)
	for emotion_name in triggered:
		show_emotion(emotion_name)
	for emotion_name in active_states.keys():
		var rule := _find_emotion_rule(emotion_name)
		if rule == null or rule.stat_key.is_empty():
			continue
		var current_val = GameState.player_save.get(rule.stat_key)
		if current_val == null:
			continue
		var stat_at_activation: float = active_states[emotion_name].get("stat_value", 100.0)
		if float(current_val) < stat_at_activation:
			var prob := rule.evaluate(ctx)
			if randf() >= prob:
				clear_emotion(emotion_name)

func _find_emotion_rule(emotion_name: String) -> EmotionRule:
	for rule in _emotion_rules:
		if rule.emotion_name == emotion_name:
			return rule
	return null

func _load_emotion_rules() -> Array[EmotionRule]:
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

func _load_stat_configs() -> Array[StatConfig]:
	var result: Array[StatConfig] = []
	var dir := DirAccess.open(STATS_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres"):
			var cfg = load(STATS_DIR + file)
			if cfg is StatConfig:
				result.append(cfg)
		file = dir.get_next()
	return result
