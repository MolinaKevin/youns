extends Node

signal stat_changed
signal bathroom_accident

const STATS_DIR := "res://data/stats/"
const HUNGRY_RULE_PATH   := "res://data/emotions/rules/hungry.tres"
const BATHROOM_RULE_PATH := "res://data/emotions/rules/bathroom.tres"

var _stat_configs: Array[StatConfig] = []
var _stat_accumulators: Dictionary = {}
var _emotion_block_count: int = 0
var _hungry_rule: EmotionRule = null
var _bathroom_rule: EmotionRule = null

var emotions_blocked: bool:
	get: return _emotion_block_count > 0

func _ready() -> void:
	_stat_configs = _load_stat_configs()
	if ResourceLoader.exists(HUNGRY_RULE_PATH):
		_hungry_rule = load(HUNGRY_RULE_PATH)
	if ResourceLoader.exists(BATHROOM_RULE_PATH):
		_bathroom_rule = load(BATHROOM_RULE_PATH)
	GameState.hour_ticked.connect(apply_hour_tick)

# ── Acceso genérico ───────────────────────────────────────────────────────────

func add_stat(key: String, delta: int) -> void:
	if GameState.player_save == null:
		return
	var current = GameState.player_save.get(key)
	if current == null:
		return
	GameState.player_save.set(key, clampi(int(current) + delta, 0, 100))
	stat_changed.emit()

func set_stat(key: String, value: int) -> void:
	if GameState.player_save == null:
		return
	if GameState.player_save.get(key) == null:
		return
	GameState.player_save.set(key, clampi(value, 0, 100))
	stat_changed.emit()

# ── Wrappers nombrados ────────────────────────────────────────────────────────

func block_emotions() -> void:   _emotion_block_count += 1
func unblock_emotions() -> void: _emotion_block_count = maxi(0, _emotion_block_count - 1)

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
	stat_changed.emit()

func set_weight(value: float) -> void:
	if GameState.player_save == null:
		return
	GameState.player_save.weight = maxf(0.0, value)

func add_weight(delta: float) -> void:
	set_weight(GameState.player_save.weight + delta)

func set_needs_bathroom(value: bool) -> void:
	if GameState.player_save == null:
		return
	GameState.player_save.needs_bathroom = value
	stat_changed.emit()

# ── Hambre ────────────────────────────────────────────────────────────────────

func tick_hunger(total_h: float) -> void:
	var ps := GameState.player_save
	if ps == null:
		return
	add_hambre(10)
	if ps.is_hungry and total_h >= ps.hungry_until_total_hour:
		_apply_expire_penalty(_hungry_rule)
		ps.is_hungry = false
		ps.hungry_since_total_hour = -1.0
		ps.hungry_until_total_hour = -1.0
		stat_changed.emit()
	elif not ps.is_hungry and _hungry_rule != null:
		var ctx := {"save": ps, "youn_data": null}
		if _hungry_rule.evaluate(ctx) > 0.0:
			ps.is_hungry = true
			ps.hungry_since_total_hour = total_h
			ps.hungry_until_total_hour = float(floori(total_h) + 2)
			stat_changed.emit()

# ── Baño ─────────────────────────────────────────────────────────────────────

func tick_bathroom(total_h: float) -> void:
	var ps := GameState.player_save
	if ps == null or _bathroom_rule == null:
		return
	if not ps.needs_bathroom:
		var ctx := {"save": ps, "youn_data": null}
		var prob := _bathroom_rule.evaluate(ctx)
		if prob > 0.0 and randf() < prob:
			set_needs_bathroom(true)
			ps.bathroom_need_since_total_hour = float(floori(total_h))
	elif ps.bathroom_need_since_total_hour >= 0.0:
		if total_h - ps.bathroom_need_since_total_hour >= 1.0:
			apply_bathroom_accident()

func apply_bathroom_accident() -> void:
	var ps := GameState.player_save
	if ps == null:
		return
	_apply_expire_penalty(_bathroom_rule)
	set_ganas_bano(0)
	set_needs_bathroom(false)
	ps.bathroom_need_since_total_hour = -1.0
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
	ps.is_hungry = false
	ps.hungry_since_total_hour = -1.0
	ps.hungry_until_total_hour = -1.0
	ps.last_meal_total_hour = GameState.get_total_hours()
	ps.ganas_bano = mini(ps.ganas_bano + 25, 100)
	stat_changed.emit()

# ── Tick por hora ─────────────────────────────────────────────────────────────

func apply_hour_tick() -> void:
	if GameState.player_save == null:
		return
	for cfg: StatConfig in _stat_configs:
		if cfg.stat_key.is_empty() or cfg.rate_per_hour == 0.0:
			continue
		var acc: float = _stat_accumulators.get(cfg.stat_key, 0.0) + cfg.rate_per_hour
		var to_apply := int(acc)
		_stat_accumulators[cfg.stat_key] = acc - float(to_apply)
		if to_apply == 0:
			continue
		var current = GameState.player_save.get(cfg.stat_key)
		if current == null:
			continue
		GameState.player_save.set(cfg.stat_key, clampi(int(current) + to_apply, int(cfg.min_value), int(cfg.max_value)))

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
