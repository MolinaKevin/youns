extends GutTest

const LabReward := preload("res://data/lab_reward.gd")

func test_reconoce_los_tipos_de_recompensa_del_laboratorio() -> void:
	assert_eq(LabReward.type_of({"type": LabReward.ITEM}), LabReward.ITEM)
	assert_true(LabReward.is_known({"type": LabReward.UNLOCK_RECIPE}))
	assert_true(LabReward.is_known({"type": LabReward.MAX_HP}))
	assert_false(LabReward.is_known({"type": "desconocido"}))
	assert_false(LabReward.is_known({}))


func test_expone_los_campos_esperados_para_cada_recompensa() -> void:
	assert_eq(LabReward.expected_fields(LabReward.ITEM), ["type", "id", "amount"])
	assert_eq(LabReward.expected_fields(LabReward.WORLD_BRIDGE), ["type", "id"])
	assert_eq(LabReward.expected_fields(LabReward.MAX_HP), ["type", "value"])
	assert_eq(LabReward.expected_fields("desconocido"), [])
