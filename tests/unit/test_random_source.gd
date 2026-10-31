extends GutTest

func test_la_misma_seed_repite_la_secuencia() -> void:
	var first := RandomSource.new(42)
	var second := RandomSource.new(42)
	assert_eq(first.randf(), second.randf())
	assert_eq(first.pick_index(10), second.pick_index(10))

func test_pick_index_vacio_no_da_indice_valido() -> void:
	assert_eq(RandomSource.new(1).pick_index(0), -1)
