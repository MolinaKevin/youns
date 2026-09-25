class_name MonsterDeck
extends Resource

## Mazo de cartas de un tipo de monstruo + sus estadísticas base.
## Las cartas modifican estas estadísticas (Mover +13, Atacar -10, ...).
## Distancias (movimiento y rango) en casillas de la grilla (CombatGrid.CELL);
## el rango se mide entre los bordes de las huellas.

## Rango de un ataque cuerpo a cuerpo, en casillas (igual que el del jugador).
const MELEE_REACH_CELLS := 13

@export var base_move: int = 63
@export var base_attack: int = 60
## 0 = cuerpo a cuerpo.
@export var base_range: int = 0
@export var cards: Array[MonsterCard] = []

func move_for(action: MonsterCardAction) -> int:
	return maxi(0, base_move + action.value)

func attack_for(action: MonsterCardAction) -> int:
	return maxi(0, base_attack + action.value)

## Rango efectivo del ataque en casillas; un ataque sin rango es cuerpo a cuerpo.
func reach_for(action: MonsterCardAction) -> int:
	var r := base_range + action.range_modifier
	return r if r > 0 else MELEE_REACH_CELLS
