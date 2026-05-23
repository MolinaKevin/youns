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

func discard_hand() -> void:
	_state.discard_pile.append_array(_state.hand)
	_state.hand.clear()

func reset_turn(hand_size: int) -> void:
	_state.player_energy = _state.max_energy
	_state.player_block = 0
	discard_hand()
	draw_cards(hand_size)
