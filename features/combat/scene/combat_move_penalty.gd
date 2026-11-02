class_name CombatMovePenalty
extends RefCounted

## Penalización de movimiento por mojado/engrasado. Jugador y enemigo la
## calculaban cada uno por su cuenta y habían divergido (16/24 casillas para
## el jugador vía CardActionLine.cells_for_modules, pero ~12,5/25 para el
## enemigo, que hardcodeaba unidades de mundo). El valor correcto es el del
## jugador: WET_MODULES/GREASY_MODULES convertidos a casillas.

const WET_MODULES := 2
const GREASY_MODULES := 3

## En casillas de grilla (lo que usa CombatPlayerActions para reducir un
## alcance ya expresado en casillas).
static func cells(wet: bool, greasy: bool) -> int:
	return (CardActionLine.cells_for_modules(WET_MODULES) if wet else 0) \
		+ (CardActionLine.cells_for_modules(GREASY_MODULES) if greasy else 0)

## En unidades de mundo (lo que usa CombatEnemyAI para reducir un alcance ya
## expresado en unidades de mundo).
static func world_units(wet: bool, greasy: bool) -> float:
	return CombatGrid.world_for(cells(wet, greasy))
