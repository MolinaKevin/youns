extends "res://tests/helpers/combat_test_case.gd"

const MapAreaScript := preload("res://features/combat/scene/map_area.gd")
const BoardFixture := preload("res://tests/helpers/combat_board_fixture.gd")

func _map_for_modules():
	return BoardFixture.empty_modules_map()

## Reglas de contacto y movimiento sobre zonas.

func test_charcos_cuestan_mp() -> void:
	for card: CardData in CardDatabase.cards_by_id.values():
		for line: CardActionLine in card.top.lines + card.bottom.lines:
			if line.card_type == "puddle":
				assert_gt(line.mp_cost, 0, card.id)


func test_danio_de_charco_a_lo_largo_de_un_segmento() -> void:
	var map = MapAreaScript.new()
	map.placement.puddles.place_puddle(Vector2(5, 5), 1.0, "fire", 3, 40)
	map.placement.puddles.place_puddle(Vector2(5, 5), 1.0, "wet")
	assert_eq(map.effects.puddle_port.zones.puddle_damage_along(Vector2(3, 5), Vector2(7, 5)), {"fire": 40})
	assert_eq(map.effects.puddle_port.zones.puddle_damage_along(Vector2(20, 20), Vector2(21, 20)), {})
	map.free()


func test_areas_exigen_contacto_de_un_tercio_de_la_huella() -> void:
	var map = _map_for_modules()
	map.actors.state.set_enemy_radius(0.3)
	map.enemy_pos = Vector2(11.09, 10.0) # radio 1 + margen de área 0,1
	assert_true(map.queries.areas.is_enemy_in_area_circle(Vector2(10, 10), 1.0))
	map.enemy_pos = Vector2(11.11, 10.0)
	assert_false(map.queries.areas.is_enemy_in_area_circle(Vector2(10, 10), 1.0))
	# La conversión de charcos conserva su intersección propia, sin este umbral.
	map.placement.puddles.place_puddle(Vector2(12.0, 10.0), 1.0, "grease")
	assert_eq(map.effects.puddle_port.mutation.convert_puddles(Vector2(10, 10), 1.0, ["grease"], "fire"), 1)
	map.free()
