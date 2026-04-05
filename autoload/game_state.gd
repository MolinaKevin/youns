extends Node

var player_save: PlayerSaveData
var current_run: RunStateData

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

	print("GameState loaded")
	print("owned ids in GameState: ", player_save.owned_card_ids)

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
