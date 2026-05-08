extends Node

signal clock_changed(current_hour: float, current_day: int)
signal stat_changed
signal clock_visibility_changed(visible: bool)
signal clock_pause_changed(paused: bool)
signal clock_style_changed(style: int)
signal youns_status_changed(discipline: int, care_mistakes: int)
signal youns_status_visibility_changed(visible: bool)

const HOURS_PER_DAY := 24.0
const DAY_DURATION_MINUTES := 1.0  # duración de un día en minutos reales
const DAY_DURATION_SECONDS := DAY_DURATION_MINUTES * 60.0
const DAY_CLOCK_SCENE: PackedScene = preload("res://features/world/ui/day_clock.tscn")
const YOUNS_STATUS_SCENE: PackedScene = preload("res://features/world/ui/youns_status_panel.tscn")
const DEBUG_STATS_SCRIPT: GDScript = preload("res://features/world/ui/debug_stats_panel.gd")

var test_mode := true

var player_save: PlayerSaveData
var current_run: RunStateData
var pending_enemy_data: EnemyData
var combat_return_pending := false
var combat_return_position := Vector3.ZERO
var combat_world_enemy_id := ""
var world_intro_seen := false
var ui_return_scene_path := ""
var current_day := 1
var time_of_day_hours := 8.0
var clock_visible := true
var clock_paused := false
var _emotion_block_count: int = 0
var emotions_blocked: bool:
	get: return _emotion_block_count > 0
var clock_style := 0  # 0 = analógico, 1 = sectores
var youns_status_visible := false
var _day_clock_ui: CanvasLayer
var _youns_status_ui: CanvasLayer
var _debug_stats_ui: CanvasLayer

const STATS_DIR := "res://data/stats/"
var _stat_configs: Array[StatConfig] = []
var _stat_accumulators: Dictionary = {}
var _last_total_hour_tick: int = 0

const SAVE_PATH := "user://player_save.tres"
const RUN_PATH := "user://current_run.tres"

func _ready() -> void:
	player_save = PlayerSaveData.new()

	# Mock para probar
	player_save.owned_card_ids = ["step", "dash", "strike", "slash", "block", "meteor", "arrow", "snipe", "grenade"]
	player_save.equipped_deck_ids = [
		"step", "step", "step",
		"dash", "dash",
		"strike", "strike", "strike",
		"slash", "slash",
		"block", "block", "block",
		"meteor", "meteor",
		"arrow", "arrow", "arrow",
		"snipe", "snipe",
		"grenade", "grenade",
		"bear_trap", "bear_trap",
		"spike_trap", "spike_trap",
	]
	player_save.inventory_slots = 20
	player_save.inventory_items = [
		{"id": "agumon_fang", "name": "Agumon Fang", "icon": "res://assets/icons/icon_1.png", "count": 3},
		{"id": "bear_plush", "name": "Bear Plush", "icon": "res://assets/icons/icon_2.png", "count": 1},
		{"id": "broken_arrow", "name": "Broken Arrow", "icon": "res://assets/icons/icon_3.png", "count": 6},
		{"id": "suero_vitalidad", "name": "Suero Vitalidad", "icon": "res://assets/icons/icon_4.png", "count": 2},
		{"id": "field_data", "name": "Field Data", "icon": "res://assets/icons/icon_5.png", "count": 8},
	]
	player_save.gold = 100

	_stat_configs = _load_stat_configs()
	_last_total_hour_tick = int(get_total_hours())

	print("GameState loaded")
	print("owned ids in GameState: ", player_save.owned_card_ids)
	_ensure_day_clock_ui()
	_ensure_youns_status_ui()
	if test_mode:
		_ensure_debug_stats_ui()
	clock_changed.emit(time_of_day_hours, current_day)
	clock_visibility_changed.emit(clock_visible)
	clock_pause_changed.emit(clock_paused)
	youns_status_changed.emit(player_save.discipline, player_save.care_mistakes)
	youns_status_visibility_changed.emit(youns_status_visible)

func _process(delta: float) -> void:
	if clock_paused:
		return
	time_of_day_hours += delta * HOURS_PER_DAY / DAY_DURATION_SECONDS
	while time_of_day_hours >= HOURS_PER_DAY:
		time_of_day_hours -= HOURS_PER_DAY
		current_day += 1
	clock_changed.emit(time_of_day_hours, current_day)
	var current_tick := int(get_total_hours())
	while _last_total_hour_tick < current_tick:
		_last_total_hour_tick += 1
		_apply_stat_rates()

func get_time_string() -> String:
	var total_minutes := int(floor(time_of_day_hours * 60.0))
	var hours := int(floor(float(total_minutes) / 60.0)) % 24
	var minutes := total_minutes % 60
	return "%02d:%02d" % [hours, minutes]

func get_time_ratio() -> float:
	return time_of_day_hours / HOURS_PER_DAY

func set_clock_visible(visible: bool) -> void:
	clock_visible = visible
	if is_instance_valid(_day_clock_ui):
		_day_clock_ui.visible = visible
	clock_visibility_changed.emit(visible)

func block_emotions() -> void:
	_emotion_block_count += 1

func unblock_emotions() -> void:
	_emotion_block_count = maxi(0, _emotion_block_count - 1)

func set_clock_paused(paused: bool) -> void:
	clock_paused = paused
	clock_pause_changed.emit(paused)

func set_clock_style(style: int) -> void:
	clock_style = style
	clock_style_changed.emit(style)

func set_youns_status_visible(visible: bool) -> void:
	youns_status_visible = visible
	if is_instance_valid(_youns_status_ui):
		_youns_status_ui.visible = visible
	youns_status_visibility_changed.emit(visible)

func has_persistent_clock_ui() -> bool:
	return test_mode or (player_save != null and player_save.clock_ui_unlocked)

func has_persistent_care_ui() -> bool:
	return player_save != null and player_save.care_ui_unlocked

func sync_overworld_ui_visibility() -> void:
	set_clock_visible(has_persistent_clock_ui())
	set_youns_status_visible(has_persistent_care_ui())

func set_discipline(value: int) -> void:
	if player_save == null:
		return
	player_save.discipline = clampi(value, 0, 100)
	_emit_youns_status_changed()

func add_discipline(delta: int) -> void:
	set_discipline(player_save.discipline + delta)

func set_felicidad(value: int) -> void:
	if player_save == null:
		return
	player_save.felicidad = clampi(value, 0, 100)
	_notify_stat_changed()

func add_felicidad(delta: int) -> void:
	set_felicidad(player_save.felicidad + delta)

func add_care_mistake(amount: int = 1) -> void:
	if player_save == null:
		return
	player_save.care_mistakes = clampi(player_save.care_mistakes + amount, 0, 10)
	_emit_youns_status_changed()

func clear_care_mistakes() -> void:
	if player_save == null:
		return
	player_save.care_mistakes = 0
	_emit_youns_status_changed()

func set_confianza(value: int) -> void:
	if player_save == null:
		return
	player_save.confianza = clampi(value, 0, 100)

func add_confianza(delta: int) -> void:
	set_confianza(player_save.confianza + delta)

func set_estres(value: int) -> void:
	if player_save == null:
		return
	player_save.estres = clampi(value, 0, 100)
	_notify_stat_changed()

func add_estres(delta: int) -> void:
	set_estres(player_save.estres + delta)

func set_aburrimiento(value: int) -> void:
	if player_save == null:
		return
	player_save.aburrimiento = clampi(value, 0, 100)
	_notify_stat_changed()

func add_aburrimiento(delta: int) -> void:
	set_aburrimiento(player_save.aburrimiento + delta)

func set_autocontrol(value: int) -> void:
	if player_save == null:
		return
	player_save.autocontrol = clampi(value, 0, 100)

func add_autocontrol(delta: int) -> void:
	set_autocontrol(player_save.autocontrol + delta)

func set_energia(value: int) -> void:
	if player_save == null:
		return
	player_save.energia = clampi(value, 0, 100)
	_notify_stat_changed()

func add_energia(delta: int) -> void:
	set_energia(player_save.energia + delta)

func drain_energia(amount: int) -> void:
	add_energia(-amount)
	_check_sick_chance()

func _check_sick_chance() -> void:
	if player_save == null or player_save.enfermo:
		return
	var salud := player_save.salud
	if salud >= 80:
		return
	# t=0 en salud=80, t=1 en salud=5 (capped)
	var t := clampf((80.0 - float(salud)) / 75.0, 0.0, 1.0)
	# curva exponencial: 0% en t=0, 60% en t=1
	const K := 3.5
	var prob := 0.60 * (exp(K * t) - 1.0) / (exp(K) - 1.0)
	if randf() < prob:
		set_enfermo(true)

func set_salud(value: int) -> void:
	if player_save == null:
		return
	player_save.salud = clampi(value, 0, 100)

func add_salud(delta: int) -> void:
	set_salud(player_save.salud + delta)

func set_enfermo(value: bool) -> void:
	if player_save == null:
		return
	player_save.enfermo = value
	_notify_stat_changed()

func set_weight(value: float) -> void:
	if player_save == null:
		return
	player_save.weight = maxf(0.0, value)

func add_weight(delta: float) -> void:
	set_weight(player_save.weight + delta)

func get_total_hours() -> float:
	return current_day * 24.0 + time_of_day_hours

func add_hambre(delta: int) -> void:
	if player_save == null:
		return
	player_save.hambre = clampi(player_save.hambre + delta, 0, 100)
	_notify_stat_changed()

func on_meal_eaten() -> void:
	if player_save == null:
		return
	player_save.hambre = 0
	_notify_stat_changed()

func set_ganas_bano(value: int) -> void:
	if player_save == null:
		return
	player_save.ganas_bano = clampi(value, 0, 100)
	_notify_stat_changed()

func set_needs_bathroom(value: bool) -> void:
	if player_save == null:
		return
	player_save.needs_bathroom = value
	_notify_stat_changed()

func _notify_stat_changed() -> void:
	stat_changed.emit()
	player_save.hungry_since_total_hour = -1.0
	player_save.last_meal_total_hour = get_total_hours()
	player_save.ganas_bano = mini(player_save.ganas_bano + 25, 100)

func _ensure_day_clock_ui() -> void:
	if is_instance_valid(_day_clock_ui):
		return
	_day_clock_ui = CanvasLayer.new()
	_day_clock_ui.name = "GlobalDayClock"
	_day_clock_ui.layer = 50
	_day_clock_ui.process_mode = Node.PROCESS_MODE_ALWAYS

	var clock := DAY_CLOCK_SCENE.instantiate()
	clock.offset_left = 16.0
	clock.offset_top = 16.0
	clock.offset_right = 126.0
	clock.offset_bottom = 126.0
	_day_clock_ui.add_child(clock)
	get_tree().root.call_deferred("add_child", _day_clock_ui)

func _ensure_youns_status_ui() -> void:
	if is_instance_valid(_youns_status_ui):
		return
	_youns_status_ui = CanvasLayer.new()
	_youns_status_ui.name = "GlobalYounsStatus"
	_youns_status_ui.layer = 45
	_youns_status_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	_youns_status_ui.visible = youns_status_visible

	var panel: Control = YOUNS_STATUS_SCENE.instantiate()
	panel.offset_left = 16.0
	panel.offset_top = 714.0
	panel.offset_right = 292.0
	panel.offset_bottom = 884.0
	_youns_status_ui.add_child(panel)
	get_tree().root.call_deferred("add_child", _youns_status_ui)

func _ensure_debug_stats_ui() -> void:
	if is_instance_valid(_debug_stats_ui):
		return
	_debug_stats_ui = CanvasLayer.new()
	_debug_stats_ui.name = "GlobalDebugStats"
	_debug_stats_ui.layer = 80
	_debug_stats_ui.process_mode = Node.PROCESS_MODE_ALWAYS

	var panel := PanelContainer.new()
	panel.set_script(DEBUG_STATS_SCRIPT)
	panel.anchor_left = 1.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -196.0
	panel.offset_top = 16.0
	panel.offset_right = -16.0
	panel.offset_bottom = 246.0
	_debug_stats_ui.add_child(panel)
	get_tree().root.call_deferred("add_child", _debug_stats_ui)

func _emit_youns_status_changed() -> void:
	youns_status_changed.emit(player_save.discipline, player_save.care_mistakes)

func load_player_save() -> void:
	if ResourceLoader.exists(SAVE_PATH):
		player_save = ResourceLoader.load(SAVE_PATH)
	else:
		player_save = PlayerSaveData.new()
		save_player_save()

func save_player_save() -> void:
	ResourceSaver.save(player_save, SAVE_PATH)

func load_run_state() -> void:
	if ResourceLoader.exists(RUN_PATH):
		current_run = ResourceLoader.load(RUN_PATH)
	else:
		current_run = RunStateData.new()

func save_run_state() -> void:
	ResourceSaver.save(current_run, RUN_PATH)

func reset_run_state() -> void:
	current_run = RunStateData.new()
	save_run_state()


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


func _apply_stat_rates() -> void:
	if player_save == null:
		return
	for cfg: StatConfig in _stat_configs:
		if cfg.stat_key.is_empty() or cfg.rate_per_hour == 0.0:
			continue
		var acc: float = _stat_accumulators.get(cfg.stat_key, 0.0) + cfg.rate_per_hour
		var to_apply := int(acc)
		_stat_accumulators[cfg.stat_key] = acc - float(to_apply)
		if to_apply == 0:
			continue
		var current = player_save.get(cfg.stat_key)
		if current == null:
			continue
		player_save.set(cfg.stat_key, clampi(int(current) + to_apply, int(cfg.min_value), int(cfg.max_value)))
