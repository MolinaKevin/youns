class_name CombatDeckFlow
extends RefCounted

## Inicialización pura del mazo del jugador. La UI de combate decide cuándo
## mostrarlo; esta clase sólo deja el estado listo y reproducible.

var _state: CombatState
var _random: RandomSource

func _init(state: CombatState, random: RandomSource) -> void:
	_state = state
	_random = random

func setup(cards: Array[CardData]) -> void:
	_state.draw_pile.assign(cards)
	_random.shuffle(_state.draw_pile)
	_state.discard_pile.clear()
	_state.hand.clear()
