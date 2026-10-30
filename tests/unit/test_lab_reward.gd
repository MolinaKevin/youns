extends GutTest

const LabRewardScript := preload("res://data/lab_reward.gd")

func test_reconoce_los_tipos_de_recompensa_del_laboratorio() -> void:
	assert_eq(LabRewardScript.type_of({"type": LabRewardScript.ITEM}), LabRewardScript.ITEM)
	assert_true(LabRewardScript.is_known({"type": LabRewardScript.UNLOCK_RECIPE}))
	assert_true(LabRewardScript.is_known({"type": LabRewardScript.MAX_HP}))
	assert_false(LabRewardScript.is_known({"type": "desconocido"}))
	assert_false(LabRewardScript.is_known({}))


func test_expone_los_campos_esperados_para_cada_recompensa() -> void:
	assert_eq(LabRewardScript.expected_fields(LabRewardScript.ITEM), ["type", "id", "amount"])
	assert_eq(LabRewardScript.expected_fields(LabRewardScript.WORLD_BRIDGE), ["type", "id"])
	assert_eq(LabRewardScript.expected_fields(LabRewardScript.MAX_HP), ["type", "value"])
	assert_eq(LabRewardScript.expected_fields("desconocido"), [])
