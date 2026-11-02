class_name StatsServicesAdapter
extends RefCounted

## Punto de entrada pequeño para los servicios de cuidado, emociones y etapa.
## Los consumidores no necesitan conocer el ensamblado interno de StatsManager.

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
