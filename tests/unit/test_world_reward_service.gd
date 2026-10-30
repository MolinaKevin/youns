extends GutTest

const WorldRewardServiceScript := preload("res://shared/world_reward_service.gd")

var _previous_save: PlayerSaveData


func before_each() -> void:
	_previous_save = GameState.save_service.player_save
	GameState.save_service.player_save = PlayerSaveData.new()


func after_each() -> void:
	GameState.save_service.player_save = _previous_save


func test_grant_mission_la_guarda_y_no_la_duplica() -> void:
	assert_true(WorldRewardServiceScript.grant_mission("test_mission", "mission.clear_tall_grass"))
	assert_true(GameState.save_service.player_save.world_progress.has_mission("test_mission"))
	assert_false(WorldRewardServiceScript.grant_mission("test_mission", "mission.clear_tall_grass"))


func test_grant_recipe_la_guarda_y_no_la_duplica() -> void:
	assert_true(WorldRewardServiceScript.grant_recipe("test_recipe"))
	assert_true(LaboratoryState.is_recipe_unlocked("test_recipe"))
	assert_false(WorldRewardServiceScript.grant_recipe("test_recipe"))
