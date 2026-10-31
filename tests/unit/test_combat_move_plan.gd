extends GutTest

const MovePlan := preload("res://features/combat/scene/combat_move_plan.gd")


func test_serializa_y_lee_un_plan_de_movimiento() -> void:
	var original = MovePlan.make(Vector2(4.0, 7.0), [Vector2i(1, 2), Vector2i(2, 2)])
	var restored = MovePlan.parse(original.to_dictionary())
	assert_eq(restored.destination, Vector2(4.0, 7.0))
	assert_eq(restored.path, [Vector2i(1, 2), Vector2i(2, 2)])


func test_diccionario_invalido_no_produce_plan() -> void:
	assert_null(MovePlan.parse({}))
