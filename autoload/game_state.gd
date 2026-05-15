extends Node

signal clock_changed(current_hour: float, current_day: int)
signal twenty_min_ticked

const HOURS_PER_DAY := 24.0
const DAY_DURATION_MINUTES := 24.0
const DAY_DURATION_SECONDS := DAY_DURATION_MINUTES * 60.0

const SAVE_PATH := "user://player_save.tres"
const RUN_PATH := "user://current_run.tres"

var test_mode := true

var player_save: PlayerSaveData
var current_run: RunStateData
var pending_enemy_data: EnemyData
var pending_wild_youn_data
var combat_return_pending := false
var combat_return_position := Vector3.ZERO
var combat_world_enemy_id := ""
var world_intro_seen := false
var ui_return_scene_path := ""
var current_day := 1
var time_of_day_hours := 8.0
var clock_paused := false

var _last_total_twenty_min_tick: int = 0

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

	_last_total_twenty_min_tick = int(get_total_hours() * 3.0)

	print("GameState loaded")
	print("owned ids in GameState: ", player_save.owned_card_ids)
	clock_changed.emit(time_of_day_hours, current_day)

func _process(delta: float) -> void:
	if clock_paused:
		return
	time_of_day_hours += delta * HOURS_PER_DAY / DAY_DURATION_SECONDS
	while time_of_day_hours >= HOURS_PER_DAY:
		time_of_day_hours -= HOURS_PER_DAY
		current_day += 1
	clock_changed.emit(time_of_day_hours, current_day)
	var current_twenty_tick := int(get_total_hours() * 3.0)
	while _last_total_twenty_min_tick < current_twenty_tick:
		_last_total_twenty_min_tick += 1
		twenty_min_ticked.emit()

func get_time_string() -> String:
	var total_minutes := int(floor(time_of_day_hours * 60.0))
	var hours := int(floor(float(total_minutes) / 60.0)) % 24
	var minutes := total_minutes % 60
	return "%02d:%02d" % [hours, minutes]

func get_time_ratio() -> float:
	return time_of_day_hours / HOURS_PER_DAY

func get_total_hours() -> float:
	return current_day * 24.0 + time_of_day_hours

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
