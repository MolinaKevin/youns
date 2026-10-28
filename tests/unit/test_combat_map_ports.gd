extends GutTest

const QueriesPort := preload("res://features/combat/scene/combat_map_queries_port.gd")
const ActorsPort := preload("res://features/combat/scene/combat_map_actors_port.gd")
const PresentationPort := preload("res://features/combat/scene/combat_map_presentation_port.gd")
const MovementPort := preload("res://features/combat/scene/combat_map_movement_port.gd")
const TerrainPort := preload("res://features/combat/scene/combat_map_terrain_port.gd")
const EnemyBoardPort := preload("res://features/combat/scene/combat_enemy_board_port.gd")


func test_las_fachadas_reales_implementan_los_puertos_de_combate() -> void:
	assert_is(CombatMapQueries.new(), QueriesPort)
	assert_is(CombatMapActors.new(), ActorsPort)
	assert_is(CombatMapPresentation.new(), PresentationPort)
	assert_is(CombatMapMovement.new(), MovementPort)
	assert_is(CombatMapTerrain.new(), TerrainPort)


func test_el_adaptador_del_tablero_enemigo_implementa_su_puerto() -> void:
	var map_area := CombatMapArea.new()
	assert_is(CombatEnemyBoardMapAdapter.new(map_area), EnemyBoardPort)
	map_area.free()
