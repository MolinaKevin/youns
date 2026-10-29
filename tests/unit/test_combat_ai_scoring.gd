extends "res://tests/helpers/combat_test_case.gd"

## Scoring de acciones de la IA enemiga.

func test_ai_score_hp_normal_no_aplica_multiplicador() -> void:
	var s := CombatState.new()
	s.enemy_hp = 35
	s.enemy_max_hp = 35
	var action := AiAction.new()
	action.base_score = 50.0
	action.score_multiplier_low_hp = 2.0
	var score: float = _make_ai(s).score_action(action)
	assert_almost_eq(score, 50.0, 0.01)

func test_ai_score_hp_bajo_30_porciento_aplica_multiplicador() -> void:
	var s := CombatState.new()
	s.enemy_hp = 5
	s.enemy_max_hp = 35
	var action := AiAction.new()
	action.base_score = 50.0
	action.score_multiplier_low_hp = 2.0
	var score: float = _make_ai(s).score_action(action)
	assert_almost_eq(score, 100.0, 0.01)

func test_ai_score_hp_exactamente_30_porciento_no_aplica_multiplicador() -> void:
	var s := CombatState.new()
	s.enemy_hp = 3
	s.enemy_max_hp = 10
	var action := AiAction.new()
	action.base_score = 50.0
	action.score_multiplier_low_hp = 2.0
	var score: float = _make_ai(s).score_action(action)
	assert_almost_eq(score, 50.0, 0.01)
