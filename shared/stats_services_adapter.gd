class_name StatsServicesAdapter
extends StatsServicesPort

var _care: CareStatsService
var _emotions: EmotionService
var _life: StatsLifeStage

func _init(care: CareStatsService, emotions: EmotionService, life: StatsLifeStage) -> void:
	_care = care
	_emotions = emotions
	_life = life

func care() -> CareStatsService:
	return _care

func emotions() -> EmotionService:
	return _emotions

func life() -> StatsLifeStage:
	return _life
