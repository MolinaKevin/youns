class_name StatsServicesPort
extends RefCounted

## Punto de entrada pequeño para los servicios de cuidado, emociones y etapa.
## Los consumidores no necesitan conocer el ensamblado interno de StatsManager.
func care() -> CareStatsService:
	return null

func emotions() -> EmotionService:
	return null

func life() -> StatsLifeStage:
	return null
