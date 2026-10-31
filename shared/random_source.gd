class_name RandomSource
extends RefCounted

## Fuente de azar inyectable: los tests pueden fijar una seed sin depender del
## generador global de Godot.

var _rng := RandomNumberGenerator.new()

func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()

func randf() -> float:
	return _rng.randf()

func pick_index(size: int) -> int:
	return _rng.randi_range(0, size - 1) if size > 0 else -1

func shuffle(values: Array) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var value = values[i]
		values[i] = values[j]
		values[j] = value

func pick(values: Array) -> Variant:
	var index := pick_index(values.size())
	return values[index] if index >= 0 else null
