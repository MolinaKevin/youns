class_name StatsServicesAdapter
extends StatsServicesPort

var _care: CareStatsService
var _emotions: EmotionService
var _life: StatsLifeStage

func _init(care_service: CareStatsService, emotion_service: EmotionService, life_stage: StatsLifeStage) -> void:
	_care = care_service
	_emotions = emotion_service
	_life = life_stage

func care() -> CareStatsService:
	return _care

func emotions() -> EmotionService:
	return _emotions

func life() -> StatsLifeStage:
	return _life
