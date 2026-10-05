extends ItemEffect
class_name ItemEffectMeal

## El ítem es una comida: baja el hambre lo que llene esta comida, suma ganas de
## ir al baño, sube la salud, registra la hora de la comida y le quita la emoción de hambre
## (ver StatsManager.on_meal_eaten).

## Ganas de baño que suma si la comida no define las suyas.
const DEFAULT_BATHROOM_GAIN := 30
## Salud que suma si la comida no define la suya.
const DEFAULT_HEALTH_GAIN := 5

## Cuánto baja el hambre.
@export_range(0, 100, 1) var fills: int = 25
## Ganas de baño que suma; -1 = DEFAULT_BATHROOM_GAIN.
@export_range(-1, 100, 1) var bathroom_gain: int = -1
## Salud que suma (o resta, si es negativo); null = DEFAULT_HEALTH_GAIN.
## En el inspector: elegir el tipo int y poner el número.
@export var health_gain: Variant = null

func apply(_save: PlayerSaveData) -> void:
	StatsManager.add_hambre(-fills)
	StatsManager.add_stat("ganas_bano", bathroom_gain if bathroom_gain >= 0 else DEFAULT_BATHROOM_GAIN)
	StatsManager.add_salud(DEFAULT_HEALTH_GAIN if health_gain == null else int(health_gain))
	StatsManager.on_meal_eaten()
