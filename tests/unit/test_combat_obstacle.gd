extends GutTest

const CombatObstacleScript := preload("res://features/combat/scene/combat_obstacle.gd")


func test_reconoce_los_tipos_de_obstaculo_del_combate() -> void:
	for obstacle_type in CombatObstacleScript.TYPES:
		assert_true(CombatObstacleScript.is_known({"type": obstacle_type}))
	assert_true(CombatObstacleScript.is_known({}), "Sin tipo debe usar solid por defecto")
	assert_false(CombatObstacleScript.is_known({"type": "lava"}))


func test_type_of_usa_solid_como_valor_por_defecto() -> void:
	assert_eq(CombatObstacleScript.type_of({}), CombatObstacleScript.SOLID)
	assert_eq(CombatObstacleScript.type_of({"type": CombatObstacleScript.PLATFORM}), CombatObstacleScript.PLATFORM)
