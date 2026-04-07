class_name AiStrategy
extends Resource

## Define el conjunto de acciones posibles para un tipo de enemigo.
## El evaluador prueba todas las acciones cada turno y ejecuta la de mayor score.

@export var actions: Array[AiAction] = []
