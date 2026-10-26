class_name CombatState
extends RefCounted
const CombatEffect := preload("res://features/combat/scene/combat_effect.gd")

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

var hand: Array[CardData] = []
## Las dos mitades elegidas este turno (superior de una carta, inferior de la otra).
var turn_actions: Array = []
var draw_pile: Array = []
var discard_pile: Array = []

## Ecos juntados jugando cartas en este combate (echo_id -> cantidad). Se
## acreditan al depósito del laboratorio solo si se gana (CombatResultFlow).
var echoes_earned: Dictionary = {}

## Duración real de un estado para quien lo recibe: la base menos su
## reducción por resistencia, nunca menos de 1.
func status_turns(base: int, on_player: bool) -> int:
	var reduction := player_status_reduction if on_player else enemy_status_reduction
	return maxi(1, base - reduction)

## Aplica un estado al jugador por `base` turnos (menos su resistencia).
func set_player_status(effect: String, base: int) -> int:
	var turns := status_turns(base, true)
	if CombatEffect.status_field(effect).is_empty(): return 0
	set_status_value(effect, true, maxi(status_value(effect, true), turns))
	return turns

## Aplica un estado al enemigo por `base` turnos (menos su resistencia).
## Devuelve los turnos que quedó (0 si el estado no existe).
func set_enemy_status(effect: String, base: int) -> int:
	var turns := status_turns(base, false)
	if CombatEffect.status_field(effect).is_empty(): return 0
	set_status_value(effect, false, maxi(status_value(effect, false), turns))
	return turns

## Turnos/stacks actuales de un estado, sin pasar por reflexión de string.
func status_value(effect: String, on_player: bool) -> int:
	match CombatEffect.status_field(effect):
		"wet_turns": return player_wet_turns if on_player else enemy_wet_turns
		"burning_turns": return player_burning_turns if on_player else enemy_burning_turns
		"greasy_turns": return player_greasy_turns if on_player else enemy_greasy_turns
		"entangled_turns": return player_entangled_turns if on_player else enemy_entangled_turns
		"bleeding_turns": return player_bleeding_turns if on_player else enemy_bleeding_turns
		"poison_stacks": return player_poison_stacks if on_player else enemy_poison_stacks
		"blinded_turns": return player_blinded_turns if on_player else enemy_blinded_turns
		"frozen_turns": return player_frozen_turns if on_player else enemy_frozen_turns
		_: return 0

## Fija los turnos/stacks de un estado directo (sin el máximo de
## set_player_status/set_enemy_status). Lo usa CombatRoundResolver para
## descontar un turno al expirar.
func set_status_value(effect: String, on_player: bool, value: int) -> void:
	match CombatEffect.status_field(effect):
		"wet_turns":
			if on_player: player_wet_turns = value
			else: enemy_wet_turns = value
		"burning_turns":
			if on_player: player_burning_turns = value
			else: enemy_burning_turns = value
		"greasy_turns":
			if on_player: player_greasy_turns = value
			else: enemy_greasy_turns = value
		"entangled_turns":
			if on_player: player_entangled_turns = value
			else: enemy_entangled_turns = value
		"bleeding_turns":
			if on_player: player_bleeding_turns = value
			else: enemy_bleeding_turns = value
		"poison_stacks":
			if on_player: player_poison_stacks = value
			else: enemy_poison_stacks = value
		"blinded_turns":
			if on_player: player_blinded_turns = value
			else: enemy_blinded_turns = value
		"frozen_turns":
			if on_player: player_frozen_turns = value
			else: enemy_frozen_turns = value

## Daño por turno de un estado para quien lo recibe (lo fija el charco que lo
## causó). Sin efecto para estados que no dañan por turno.
func set_status_damage(effect: String, on_player: bool, value: int) -> void:
	match effect:
		CombatEffect.BURN:
			if on_player: player_burn_damage = value
			else: enemy_burn_damage = value
		CombatEffect.BLEED:
			if on_player: player_bleed_damage = value
			else: enemy_bleed_damage = value
		CombatEffect.POISON:
			if on_player: player_poison_damage = value
			else: enemy_poison_damage = value

## Cura al jugador sin pasar su máximo. Devuelve lo curado.
func heal_player(amount: int) -> int:
	var before := player_hp
	player_hp = clampi(player_hp + amount, player_hp, player_max_hp)
	return player_hp - before

## Saca los estados negativos del jugador. Devuelve si tenía alguno.
func cleanse_player() -> bool:
	var had := player_wet_turns > 0 or player_burning_turns > 0 or player_greasy_turns > 0 \
		or player_entangled_turns > 0 or player_bleeding_turns > 0 or player_poison_stacks > 0 \
		or player_blinded_turns > 0 or player_frozen_turns > 0
	player_wet_turns = 0
	player_burning_turns = 0
	player_greasy_turns = 0
	player_entangled_turns = 0
	player_bleeding_turns = 0
	player_poison_stacks = 0
	player_blinded_turns = 0
	player_frozen_turns = 0
	return had

## El MP no se recupera solo: solo con líneas "mp_restore". Devuelve lo
## recuperado (nunca pasa el máximo).
func restore_mp(amount: int) -> int:
	var before := player_mp
	player_mp = clampi(player_mp + amount, 0, player_max_mp)
	return player_mp - before

## Resumen de estados para mostrar sobre cada personaje: "Fuego 2 · Bloqueo 30".
func status_summary(for_player: bool) -> String:
	var parts: PackedStringArray = []
	for status in CombatEffect.STATUS_SUMMARY_ORDER:
		var value := status_value(status, for_player)
		if value > 0:
			var key: String = "burning" if status == CombatEffect.BURN else ("bleeding" if status == CombatEffect.BLEED else ("greasy" if status == CombatEffect.SLOW else ("entangled" if status == CombatEffect.ENTANGLE else ("frozen" if status == CombatEffect.FREEZE else ("blinded" if status == CombatEffect.BLIND else status)))))
			parts.append(LocalizationState.t("combat.status_summary.%s" % key, [value]))
	var block := player_block if for_player else enemy_block
	if block > 0:
		parts.append(LocalizationState.t("combat.status_summary.block", [block]))
	var ward := player_ward if for_player else enemy_ward
	if ward > 0:
		parts.append(LocalizationState.t("combat.status_summary.ward", [ward]))
	if for_player:
		if player_counter_damage > 0:
			parts.append(LocalizationState.t("combat.status_summary.counterattack", [player_counter_damage]))
		if player_enchant_damage > 0:
			parts.append(LocalizationState.t("combat.status_summary.enchanted_weapon"))
		if player_in_tree:
			parts.append(LocalizationState.t("combat.status_summary.in_tree"))
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
