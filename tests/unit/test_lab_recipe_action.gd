extends GutTest

const LabRecipeAction := preload("res://data/lab_recipe_action.gd")


func test_reconoce_los_tipos_de_accion_del_laboratorio() -> void:
	assert_true(LabRecipeAction.is_known(LabRecipeAction.INSTANT))
	assert_true(LabRecipeAction.is_known(LabRecipeAction.LOOP))
	assert_true(LabRecipeAction.is_known(LabRecipeAction.UPGRADE))
	assert_true(LabRecipeAction.is_known(LabRecipeAction.NEXT))
	assert_true(LabRecipeAction.is_known(LabRecipeAction.DUNGEON))
	assert_false(LabRecipeAction.is_known("unknown"))
