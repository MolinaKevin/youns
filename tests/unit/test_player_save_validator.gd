extends GutTest

const Validator := preload("res://shared/player_save_validator.gd")


func test_sanea_valores_numericos_fuera_de_rango() -> void:
	var save := PlayerSaveData.new()
	save.gold = -4
	save.player_level = 0
	save.discipline = -1
	save.felicidad = 101
	save.energia = 120
	save.hambre = -2
	save.weight = -1.0
	save.lives = -3
	save.lab_data_cost_reduction = 3.0
	save.lab_combat_recovery_percent = -1.0

	Validator.sanitize(save)

	assert_eq(save.gold, 0)
	assert_eq(save.player_level, 1)
	assert_eq(save.discipline, 0)
	assert_eq(save.felicidad, 100)
	assert_eq(save.energia, 100)
	assert_eq(save.hambre, 0)
	assert_eq(save.weight, 0.0)
	assert_eq(save.lives, 0)
	assert_eq(save.lab_data_cost_reduction, 0.9)
	assert_eq(save.lab_combat_recovery_percent, 0.0)
