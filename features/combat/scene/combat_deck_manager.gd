class_name CombatDeckManager
extends RefCounted

signal reshuffled

var _state: CombatState

func setup(p_state: CombatState) -> void:
	_state = p_state

func draw_cards(n: int) -> void:
	for i in n:
		if _state.draw_pile.is_empty():
			if _state.discard_pile.is_empty():
				break
			_state.draw_pile.assign(_state.discard_pile)
			_state.draw_pile.shuffle()
			_state.discard_pile.clear()
			reshuffled.emit()
		_state.hand.append(_state.draw_pile.pop_back())

## keep_indices: índices de state.hand que se quedan en la mano (comodín "mantener carta").
func discard_hand(keep_indices: Array = []) -> void:
	var kept := []
	for i in _state.hand.size():
		if keep_indices.has(i):
			kept.append(_state.hand[i])
		else:
			_state.discard_pile.append(_state.hand[i])
	_state.hand.assign(kept)

## Descarta la mano (salvo las cartas mantenidas) y roba hasta tener hand_size.
func reset_turn(hand_size: int, keep_indices: Array = []) -> void:
	_state.turn_actions.clear()
	_state.player_block = 0
	_state.player_ward = 0
	_state.player_counter_damage = 0
	_state.player_enchant_damage = 0
	_state.player_enchant_status = ""
	# El bloqueo y el escudo mágico duran una ronda, también los del enemigo.
	_state.enemy_block = 0
	_state.enemy_ward = 0
	discard_hand(keep_indices)
	draw_cards(hand_size - _state.hand.size())
