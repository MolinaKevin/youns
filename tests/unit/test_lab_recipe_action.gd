extends GutTest

const LabRecipeActionScript := preload("res://data/lab_recipe_action.gd")


func test_reconoce_los_tipos_de_accion_del_laboratorio() -> void:
	assert_true(LabRecipeActionScript.is_known(LabRecipeActionScript.INSTANT))
	assert_true(LabRecipeActionScript.is_known(LabRecipeActionScript.LOOP))
	assert_true(LabRecipeActionScript.is_known(LabRecipeActionScript.UPGRADE))
	assert_true(LabRecipeActionScript.is_known(LabRecipeActionScript.NEXT))
	assert_true(LabRecipeActionScript.is_known(LabRecipeActionScript.DUNGEON))
	assert_false(LabRecipeActionScript.is_known("unknown"))
