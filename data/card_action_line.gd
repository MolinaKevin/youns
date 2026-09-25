extends Resource
class_name CardActionLine

## Una línea de acción dentro de una mitad de carta ("Mover 2", "Atacar 3"...).
## Las líneas de una mitad se ejecutan en orden. Cada campo se interpreta según
## card_type (p. ej. card_range es la distancia en "move" y el radio en "puddle").

@export var card_type: String
## Texto libre de la línea. Por ahora solo se guarda, no se muestra en ningún lado.
@export var description: String = ""
@export var card_range: int = 0
@export var damage: int = 0
@export var block_amount: int = 0
@export var bounce: float = 0.0
@export var throw_range: int = 0
@export var puddle_effect: String = "wet"
## Una línea desactivada se muestra atenuada y no se ejecuta.
@export var enabled: bool = true

@export_group("Escalado con estadísticas")
## Si tienen escalado, estos valores se calculan con las estadísticas del Youn
## (ver resolved()); si no, se usa el valor fijo de arriba.
@export var damage_scaling: StatScaling
@export var block_scaling: StatScaling
## Escala card_range (movimiento, rango o radio según el tipo).
@export var range_scaling: StatScaling
@export var throw_scaling: StatScaling
@export_group("")

## Nombre de la carta dueña; se completa en runtime para los logs de combate.
var name: String = ""

## Copia de la línea con los valores finales para esas estadísticas: es lo que
## se muestra en la carta y lo que se ejecuta en combate.
func resolved(stats: Dictionary) -> CardActionLine:
	var r := duplicate() as CardActionLine
	r.name = name
	if damage_scaling != null:
		r.damage = damage_scaling.evaluate(stats)
	if block_scaling != null:
		r.block_amount = block_scaling.evaluate(stats)
	if range_scaling != null:
		r.card_range = range_scaling.evaluate(stats)
	if throw_scaling != null:
		r.throw_range = throw_scaling.evaluate(stats)
	return r
