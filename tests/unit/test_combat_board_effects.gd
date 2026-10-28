extends "res://tests/helpers/combat_test_case.gd"

## Pruebas de charcos, módulos, árboles, hechizos y reglas del terreno.

# ── Charcos en el mapa: duración ─────────────────────────────────────────────

const MapAreaScript := preload("res://features/combat/scene/map_area.gd")
const BoardFixture := preload("res://tests/helpers/combat_board_fixture.gd")

func _map_for_modules():
	return BoardFixture.empty_modules_map()


func test_arrastre_acerca_al_enemigo_sin_pasarse() -> void:
	var map = MapAreaScript.new()
	map.enemy_pos = Vector2(2, 2)
	assert_eq(map.push.queries.calculate_drag_landing(Vector2(2, 10), 3.0), Vector2(2, 5))
	assert_eq(map.push.queries.calculate_drag_landing(Vector2(2, 10), 20.0), Vector2(2, 10))
	map.free()


func test_arrastre_se_frena_en_un_obstaculo() -> void:
	var map = MapAreaScript.new()
	map.enemy_pos = Vector2(14, 25)  # al sur del obstáculo sólido de (14, 19), radio 1,5
	var landing: Vector2 = map.push.queries.calculate_drag_landing(Vector2(14, 12), 20.0)
	assert_gt(landing.y, 20.5)
	map.free()
