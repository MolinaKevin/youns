class_name MonsterCard
extends Resource

## Carta de habilidad de un monstruo: se le asigna una por ronda y ejecuta
## sus acciones en orden. Menor iniciativa actúa primero.
@export var card_name: String = ""
@export var initiative: int = 50
@export var actions: Array[MonsterCardAction] = []
