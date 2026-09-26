extends Resource
class_name CardActionLine

## Una línea de acción dentro de una mitad de carta ("Mover 2", "Atacar 3"...).
## Las líneas de una mitad se ejecutan en orden. Cada campo se interpreta según
## card_type (p. ej. card_range es la distancia en "move" y el radio en "puddle").

@export var card_type: String
## Texto libre de la línea. Por ahora solo se guarda, no se muestra en ningún lado.
@export var description: String = ""
@export var card_range: int = 0
## En "puddle" es el daño por turno del estado que deja (fuego, sangre,
## veneno por acumulación); 0 = el de CombatState.
@export var damage: int = 0
## Físico lo frena el bloqueo; mágico, el escudo mágico (ver CombatState).
@export_enum("fisico", "magico") var damage_type: String = "fisico"
## Bloqueo en "block", escudo mágico en "ward".
@export var block_amount: int = 0
@export var bounce: float = 0.0
@export var throw_range: int = 0
@export var puddle_effect: String = "wet"
## Estado que aplica la línea (maldiciones, aliento, encantar arma). Ver
## CombatState.set_enemy_status.
@export_enum("ninguno", "blind", "slow", "entangle", "burn", "poison", "freeze", "wet") var status_effect: String = "ninguno"
## Módulos que rompe ("break") o levanta ("build") la línea.
@export var module_count: int = 1
## Hechizos retardados: rondas hasta que caen (1 = al terminar esta ronda).
@export var delay: int = 1
## Rondas que dura lo que deja la línea (charcos). 0 = no se va nunca.
@export var duration: int = 0
## MP que gasta la línea. Se cobra al empezar la mitad; si no alcanza, la
## mitad no se puede jugar (ver CardAction.mp_cost()).
@export var mp_cost: int = 0
## Cuánto recupera la línea: MP en "mp_restore".
@export var restore_amount: int = 0
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
@export var restore_scaling: StatScaling
@export var duration_scaling: StatScaling
@export var module_scaling: StatScaling
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
	if module_scaling != null:
		r.module_count = module_scaling.evaluate(stats)
	if duration_scaling != null:
		r.duration = duration_scaling.evaluate(stats)
	if restore_scaling != null:
		r.restore_amount = restore_scaling.evaluate(stats)
	if throw_scaling != null:
		r.throw_range = throw_scaling.evaluate(stats)
	return r
