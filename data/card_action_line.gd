extends Resource
class_name CardActionLine
const CombatEffect := preload("res://features/combat/scene/combat_effect.gd")

## Una unidad visible de movimiento equivale a varias celdas de la grilla
## interna. Las cartas hablan en módulos; el mapa conserva la precisión de
## CombatGrid.CELL para caminos, diagonales y obstáculos.
const MOVEMENT_MODULE_CELLS := 8

## Una línea de acción dentro de una mitad de carta ("Mover 2", "Atacar 3"...).
## Las líneas de una mitad se ejecutan en orden. Cada campo se interpreta según
## card_type (p. ej. card_range es la distancia en "move" y el radio en "puddle").

## Constantes para comparar card_type sin escribir el string a mano: un typo
## en TYPE_MOVE es error de compilación, un typo en "move" no. El campo sigue
## siendo String (no un enum) para no tener que resavear los .tres de cartas.
const TYPE_MOVE := "move"
const TYPE_MELEE_ATTACK := "melee_attack"
const TYPE_RANGE_ATTACK := "range_attack"
const TYPE_GRENADE := "grenade"
const TYPE_TRAP_PLACE := "trap_place"
const TYPE_TRAP_THROW := "trap_throw"
const TYPE_BLOCK := "block"
const TYPE_WARD := "ward"
const TYPE_MP_RESTORE := "mp_restore"
const TYPE_COUNTER := "counter"
const TYPE_NOVA := "nova"
const TYPE_HEAL := "heal"
const TYPE_ENCHANT := "enchant"
const TYPE_ELEMENT_BOLT := "element_bolt"
const TYPE_CHAIN_BOLT := "chain_bolt"
const TYPE_DELAYED_AREA := "delayed_area"
const TYPE_CONE_BLAST := "cone_blast"
const TYPE_CURSE := "curse"
const TYPE_BLINK := "blink"
const TYPE_PUDDLE_HOP := "puddle_hop"
const TYPE_TREE_CLIMB := "tree_climb"
const TYPE_ROCK_JUMP := "rock_jump"
const TYPE_PUSH := "push"
const TYPE_PULL := "pull"
const TYPE_ANCHOR := "anchor"
const TYPE_BREAK := "break"
const TYPE_MODULE_PUSH := "module_push"
const TYPE_BUILD := "build"
const TYPE_MODULE_THROW := "module_throw"
const TYPE_COLLAPSE := "collapse"
const TYPE_PUDDLE := "puddle"
const TYPE_OVERWATCH := "overwatch"

@export var card_type: String
## Texto libre de la línea. Por ahora solo se guarda, no se muestra en ningún lado.
@export var description: String = ""
@export var card_range: int = 0
## Con 0, una carta antigua deriva sus módulos de card_range para poder
## migrarla sin cambiar su comportamiento de golpe.
@export_group("Movimiento modular")
@export var movement_base_modules: int = 0
@export var movement_extra_modules: int = 0
@export_range(0.5, 1.5, 0.01) var movement_stat_multiplier: float = 1.0
@export_group("")
## En "puddle" es el daño por turno del estado que deja (fuego, sangre,
## veneno por acumulación); 0 = el de CombatState.
@export var damage: int = 0
## Físico lo frena el bloqueo; mágico, el escudo mágico (ver CombatState).
@export_enum("fisico", "magico") var damage_type: String = "fisico"
## Bloqueo en "block", escudo mágico en "ward".
@export var block_amount: int = 0
@export var bounce: float = 0.0
@export var throw_range: int = 0
## Dimensiones espaciales para líneas que no son movimiento. La primaria
## corresponde a card_range (alcance, radio o largo según la acción); la de
## lanzamiento corresponde a throw_range. En 0, ambas derivan sus módulos de
## los valores antiguos durante la migración.
@export_group("Patrón modular")
@export var primary_base_modules: int = 0
@export var primary_extra_modules: int = 0
@export_range(0.5, 1.5, 0.01) var primary_stat_multiplier: float = 1.0
@export var cast_base_modules: int = 0
@export var cast_extra_modules: int = 0
@export_range(0.5, 1.5, 0.01) var cast_stat_multiplier: float = 1.0
## Nulo = la línea conserva su comportamiento actual; los patrones nuevos se
## agregan de forma gradual por recurso.
@export var pattern: CardPattern
@export_group("")
@export var puddle_effect: String = CombatEffect.WET
## Estado que aplica la línea (maldiciones, aliento, encantar arma). Ver
## CombatState.set_enemy_status.
@export_enum("ninguno", "blind", "slow", "entangle", "burn", "poison", "freeze", "wet") var status_effect: String = CombatEffect.NONE
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
		var scaled_range_modules := modules_from_cells(range_scaling.evaluate(stats))
		if r.movement_base_modules > 0:
			r.movement_extra_modules = scaled_range_modules - r.movement_base_modules
		elif r.primary_base_modules > 0:
			r.primary_extra_modules = scaled_range_modules - r.primary_base_modules
		else:
			r.card_range = range_scaling.evaluate(stats)
	if module_scaling != null:
		r.module_count = module_scaling.evaluate(stats)
	if duration_scaling != null:
		r.duration = duration_scaling.evaluate(stats)
	if restore_scaling != null:
		r.restore_amount = restore_scaling.evaluate(stats)
	if throw_scaling != null:
		var scaled_cast_modules := modules_from_cells(throw_scaling.evaluate(stats))
		if r.cast_base_modules > 0:
			r.cast_extra_modules = scaled_cast_modules - r.cast_base_modules
		else:
			r.throw_range = throw_scaling.evaluate(stats)
	# Salud baja del Youn: rinden menos el daño, el bloqueo y la curación.
	var health: float = stats.get("health_factor", 1.0)
	if health < 1.0:
		r.damage = roundi(r.damage * health)
		r.block_amount = roundi(r.block_amount * health)
		r.restore_amount = roundi(r.restore_amount * health)
	return r


## Las cartas existentes usaban card_range en celdas: se redondean al módulo
## más cercano durante la transición.
func movement_modules() -> int:
	if movement_base_modules > 0:
		return movement_base_modules
	return maxi(1, roundi(float(card_range) / float(MOVEMENT_MODULE_CELLS)))


func movement_effective_modules() -> float:
	return float(movement_modules() + movement_extra_modules) * movement_stat_multiplier


func movement_range_cells() -> int:
	return movement_cells_for_modules(movement_effective_modules())


func movement_module_label() -> String:
	return movement_modules_label(movement_effective_modules())


static func movement_cells_for_modules(modules: float) -> int:
	return maxi(1, roundi(modules * MOVEMENT_MODULE_CELLS))


static func movement_modules_label(modules: float) -> String:
	var rounded := snappedf(modules, 0.1)
	return str(roundi(rounded)) if is_equal_approx(rounded, float(roundi(rounded))) else "%.1f" % rounded


static func movement_modules_label_for_cells(cells: int) -> String:
	return movement_modules_label(float(cells) / float(MOVEMENT_MODULE_CELLS))


func primary_modules() -> int:
	return primary_base_modules if primary_base_modules > 0 else modules_from_cells(card_range)


func primary_effective_modules() -> float:
	return float(primary_modules() + primary_extra_modules) * primary_stat_multiplier


func primary_range_cells() -> int:
	return cells_for_modules(primary_effective_modules())


func primary_module_label() -> String:
	return modules_label(primary_effective_modules())


func cast_modules() -> int:
	return cast_base_modules if cast_base_modules > 0 else modules_from_cells(throw_range)


func cast_effective_modules() -> float:
	return float(cast_modules() + cast_extra_modules) * cast_stat_multiplier


func cast_range_cells() -> int:
	return cells_for_modules(cast_effective_modules())


func cast_module_label() -> String:
	return modules_label(cast_effective_modules())


static func modules_from_cells(cells: int) -> int:
	return maxi(0, roundi(float(cells) / float(MOVEMENT_MODULE_CELLS)))


static func cells_for_modules(modules: float) -> int:
	return maxi(0, roundi(modules * MOVEMENT_MODULE_CELLS))


static func modules_label(modules: float) -> String:
	var rounded := snappedf(modules, 0.1)
	return str(roundi(rounded)) if is_equal_approx(rounded, float(roundi(rounded))) else "%.1f" % rounded
