extends GutTest

const CombatObstacle := preload("res://features/combat/scene/combat_obstacle.gd")


func test_reconoce_los_tipos_de_obstaculo_del_combate() -> void:
	for obstacle_type in CombatObstacle.TYPES:
		assert_true(CombatObstacle.is_known({"type": obstacle_type}))
	assert_true(CombatObstacle.is_known({}), "Sin tipo debe usar solid por defecto")
	assert_false(CombatObstacle.is_known({"type": "lava"}))


func test_type_of_usa_solid_como_valor_por_defecto() -> void:
	assert_eq(CombatObstacle.type_of({}), CombatObstacle.SOLID)
	assert_eq(CombatObstacle.type_of({"type": CombatObstacle.PLATFORM}), CombatObstacle.PLATFORM)
