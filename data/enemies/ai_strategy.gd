class_name AiStrategy
extends Resource

@export var initial_phase: String = ""
@export var phases: Array[AiPhase] = []
@export var transitions: Array[AiPhaseTransition] = []

## Lista plana de acciones — usada cuando initial_phase está vacío.
## Mantener para compatibilidad con estrategias sin fases. Retirar cuando todos
## los recursos de estrategia declaren fases y el validador rechace el formato
## plano sin romper partidas o mods soportados.
@export var actions: Array[AiAction] = []
