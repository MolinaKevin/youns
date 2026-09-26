class_name CombatState
extends RefCounted

## Vida, daño, bloqueo y curación usan números grandes (x10 respecto de la
## primera versión) para que después puedan escalar con estadísticas.
const BURN_DAMAGE := 30              # por turno en llamas
const BLEED_DAMAGE := 20             # por turno sangrando
const POISON_DAMAGE_PER_STACK := 10  # el veneno pega acumulaciones x esto

## Tipos de daño: el físico lo frena el bloqueo y el mágico, el escudo mágico.
const FISICO := "fisico"
const MAGICO := "magico"
## Tipo de daño de cada estado que hace daño por turno.
const BURN_DAMAGE_TYPE := MAGICO
const BLEED_DAMAGE_TYPE := FISICO
const POISON_DAMAGE_TYPE := MAGICO

var player_hp := 400
var player_max_hp := 400
var player_mp := 0
var player_max_mp := 0
var player_block := 0
var player_ward := 0

var enemy_hp := 350
var enemy_max_hp := 350
var enemy_block := 0
var enemy_ward := 0

## Daño por turno de cada estado: lo fija el charco que lo causó (escala con
## el espíritu de quien lo puso); si no, el valor por defecto de arriba.
var player_burn_damage: int = BURN_DAMAGE
var enemy_burn_damage: int = BURN_DAMAGE
var player_bleed_damage: int = BLEED_DAMAGE
var enemy_bleed_damage: int = BLEED_DAMAGE
var player_poison_damage: int = POISON_DAMAGE_PER_STACK
var enemy_poison_damage: int = POISON_DAMAGE_PER_STACK

## Turnos que se le restan a cada estado que recibe (sale de la resistencia,
## ver YounStatRules.status_reduction). Negativo = los estados le duran más.
var player_status_reduction: int = 0
var enemy_status_reduction: int = 0

## Contraataque de esta ronda: daño que devuelve cuando el enemigo le pega
## cuerpo a cuerpo (0 = sin contraataque). Se reinicia cada ronda.
var player_counter_damage: int = 0

## Trepar árbol: arriba del árbol los ataques del enemigo no lo alcanzan y no
## se puede mover. Al terminar la ronda cae en player_tree_landing y, si cae
## sobre el enemigo, le hace player_tree_drop_damage.
var player_in_tree: bool = false
var player_tree_landing: Vector2 = Vector2.ZERO
var player_tree_drop_damage: int = 0

## Encantar arma: el próximo ataque físico suma este daño, pasa a ser mágico y
## aplica player_enchant_status. Dura hasta usarse o hasta fin de ronda.
var player_enchant_damage: int = 0
var player_enchant_status: String = ""

var player_wet_turns: int = 0
var enemy_wet_turns:  int = 0
var player_burning_turns: int = 0
var enemy_burning_turns: int = 0
var player_greasy_turns: int = 0
var enemy_greasy_turns: int = 0
var player_entangled_turns: int = 0
var enemy_entangled_turns: int = 0
var player_bleeding_turns: int = 0
var enemy_bleeding_turns: int = 0
var player_poison_stacks: int = 0
var enemy_poison_stacks: int = 0
var player_blinded_turns: int = 0
var enemy_blinded_turns: int = 0
var player_frozen_turns: int = 0
var enemy_frozen_turns:  int = 0

var player_overwatch_active:     bool    = false
var player_overwatch_origin:     Vector2 = Vector2.ZERO
var player_overwatch_dir:        Vector2 = Vector2.ZERO
var player_overwatch_range:      float   = 0.0
var player_overwatch_half_angle: float   = 45.0
var player_overwatch_damage:     int     = 0
var player_overwatch_damage_type: String = FISICO

var hand: Array = []
## Las dos mitades elegidas este turno (superior de una carta, inferior de la otra).
var turn_actions: Array = []
var draw_pile: Array = []
var discard_pile: Array = []

## Duración real de un estado para quien lo recibe: la base menos su
## reducción por resistencia, nunca menos de 1.
func status_turns(base: int, on_player: bool) -> int:
	var reduction := player_status_reduction if on_player else enemy_status_reduction
	return maxi(1, base - reduction)

## Qué deja un charco al caerle encima a alguien (traslado de charco, hechizos
## que dejan charcos): efecto → [estado, turnos base].
const PUDDLE_IMPACTS := {
	"wet": ["wet", 3], "fire": ["burn", 3], "poison": ["poison", 3], "blood": ["bleed", 4],
	"grease": ["slow", 3], "vine": ["entangle", 2], "sand": ["blind", 2], "ice": ["freeze", 2],
}

## Un charco le cae encima al enemigo: le aplica su estado (con el daño por
## turno del charco si tiene). Devuelve [estado, turnos] o [] si no aplica nada.
func puddle_impact_on_enemy(effect: String, tick_damage: int) -> Array:
	if not PUDDLE_IMPACTS.has(effect):
		return []
	match effect:
		"fire": enemy_burn_damage = tick_damage if tick_damage > 0 else BURN_DAMAGE
		"poison": enemy_poison_damage = tick_damage if tick_damage > 0 else POISON_DAMAGE_PER_STACK
		"blood": enemy_bleed_damage = tick_damage if tick_damage > 0 else BLEED_DAMAGE
	var status: String = PUDDLE_IMPACTS[effect][0]
	return [status, set_enemy_status(status, PUDDLE_IMPACTS[effect][1])]

## Igual que puddle_impact_on_enemy, para el jugador.
func puddle_impact_on_player(effect: String, tick_damage: int) -> Array:
	if not PUDDLE_IMPACTS.has(effect):
		return []
	match effect:
		"fire": player_burn_damage = tick_damage if tick_damage > 0 else BURN_DAMAGE
		"poison": player_poison_damage = tick_damage if tick_damage > 0 else POISON_DAMAGE_PER_STACK
		"blood": player_bleed_damage = tick_damage if tick_damage > 0 else BLEED_DAMAGE
	var status: String = PUDDLE_IMPACTS[effect][0]
	return [status, set_player_status(status, PUDDLE_IMPACTS[effect][1])]

## Aplica un estado al jugador por `base` turnos (menos su resistencia).
func set_player_status(effect: String, base: int) -> int:
	var turns := status_turns(base, true)
	match effect:
		"blind": player_blinded_turns = maxi(player_blinded_turns, turns)
		"slow": player_greasy_turns = maxi(player_greasy_turns, turns)
		"entangle": player_entangled_turns = maxi(player_entangled_turns, turns)
		"burn": player_burning_turns = maxi(player_burning_turns, turns)
		"bleed": player_bleeding_turns = maxi(player_bleeding_turns, turns)
		"poison": player_poison_stacks = maxi(player_poison_stacks, turns)
		"freeze": player_frozen_turns = maxi(player_frozen_turns, turns)
		"wet": player_wet_turns = maxi(player_wet_turns, turns)
		_: return 0
	return turns

## Aplica un estado al enemigo por `base` turnos (menos su resistencia).
## Devuelve los turnos que quedó (0 si el estado no existe).
func set_enemy_status(effect: String, base: int) -> int:
	var turns := status_turns(base, false)
	match effect:
		"blind": enemy_blinded_turns = maxi(enemy_blinded_turns, turns)
		"slow": enemy_greasy_turns = maxi(enemy_greasy_turns, turns)
		"entangle": enemy_entangled_turns = maxi(enemy_entangled_turns, turns)
		"burn": enemy_burning_turns = maxi(enemy_burning_turns, turns)
		"bleed": enemy_bleeding_turns = maxi(enemy_bleeding_turns, turns)
		"poison": enemy_poison_stacks = maxi(enemy_poison_stacks, turns)
		"freeze": enemy_frozen_turns = maxi(enemy_frozen_turns, turns)
		"wet": enemy_wet_turns = maxi(enemy_wet_turns, turns)
		_: return 0
	return turns

## Cura al jugador sin pasar su máximo. Devuelve lo curado.
func heal_player(amount: int) -> int:
	var before := player_hp
	player_hp = clampi(player_hp + amount, player_hp, player_max_hp)
	return player_hp - before

## El MP no se recupera solo: solo con líneas "mp_restore". Devuelve lo
## recuperado (nunca pasa el máximo).
func restore_mp(amount: int) -> int:
	var before := player_mp
	player_mp = clampi(player_mp + amount, 0, player_max_mp)
	return player_mp - before

## Resumen de estados para mostrar sobre cada personaje: "Fuego 2 · Bloqueo 30".
func status_summary(for_player: bool) -> String:
	var p := "player_" if for_player else "enemy_"
	var parts: PackedStringArray = []
	for entry in [
		["burning_turns", "Fuego"], ["bleeding_turns", "Sangra"], ["poison_stacks", "Veneno"],
		["wet_turns", "Mojado"], ["greasy_turns", "Lento"], ["entangled_turns", "Enredado"],
		["frozen_turns", "Congelado"], ["blinded_turns", "Ciego"],
	]:
		var value: int = get(p + entry[0])
		if value > 0:
			parts.append("%s %d" % [entry[1], value])
	var block: int = get(p + "block")
	if block > 0:
		parts.append("Bloqueo %d" % block)
	var ward: int = get(p + "ward")
	if ward > 0:
		parts.append("Escudo mágico %d" % ward)
	if for_player:
		if player_counter_damage > 0:
			parts.append("Contraataque %d" % player_counter_damage)
		if player_enchant_damage > 0:
			parts.append("Arma encantada")
		if player_in_tree:
			parts.append("En el árbol")
	return " · ".join(parts)

## Aplica daño al jugador: primero lo absorbe el escudo de su tipo (bloqueo o
## escudo mágico), que se gasta. Devuelve la vida perdida.
func damage_player(amount: int, damage_type: String = FISICO) -> int:
	var dmg: int
	if damage_type == MAGICO:
		dmg = maxi(amount - player_ward, 0)
		player_ward = maxi(player_ward - amount, 0)
	else:
		dmg = maxi(amount - player_block, 0)
		player_block = maxi(player_block - amount, 0)
	player_hp -= dmg
	return dmg

## Igual que damage_player, para el enemigo.
func damage_enemy(amount: int, damage_type: String = FISICO) -> int:
	var dmg: int
	if damage_type == MAGICO:
		dmg = maxi(amount - enemy_ward, 0)
		enemy_ward = maxi(enemy_ward - amount, 0)
	else:
		dmg = maxi(amount - enemy_block, 0)
		enemy_block = maxi(enemy_block - amount, 0)
	enemy_hp -= dmg
	return dmg
