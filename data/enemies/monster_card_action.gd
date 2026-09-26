class_name MonsterCardAction
extends Resource

## Una línea de una carta de monstruo. Las cartas se ejecutan de arriba a abajo.
##   move    — se acerca al jugador: base_move + value casillas
##   retreat — se aleja del jugador: base_move + value casillas
##   attack  — base_attack + value de daño; rango base_range + range_modifier
##             casillas (0 o menos = cuerpo a cuerpo)
##   block   — gana value de bloqueo (frena daño físico)
##   ward    — gana value de escudo mágico (frena daño mágico)
##   heal    — se cura value
@export_enum("move", "retreat", "attack", "block", "ward", "heal") var type: String = "move"
## Modificador sobre la estadística base (move/retreat/attack) o valor fijo (block/heal).
@export var value: int = 0
@export var range_modifier: int = 0
## Solo en attack: físico lo frena el bloqueo; mágico, el escudo mágico.
@export_enum("fisico", "magico") var damage_type: String = "fisico"
## Texto extra opcional que se muestra debajo de la acción.
@export var note: String = ""
