class_name MenuNavigation
extends RefCounted

## Cálculo de índice compartido entre los menús que se mueven con flechas
## (title_menu: lista lineal con vuelta; main_menu: grilla sin vuelta). Cada
## menú sigue dibujando su propia selección (colores, hint, etc.) — esto solo
## decide a qué índice saltar.

## `wrap_around`: al pasar un extremo, sigue por el otro. `is_disabled`: si se
## da, saltea los índices para los que devuelve true (solo tiene sentido con
## `wrap_around`, porque sin vuelta no hay por dónde seguir buscando).
static func next_index(current: int, delta: int, count: int, wrap_around: bool, is_disabled: Callable = Callable()) -> int:
	if not wrap_around:
		var next := current + delta
		return next if next >= 0 and next < count else current
	var index := current
	for _i in count:
		index = wrapi(index + delta, 0, count)
		if not is_disabled.is_valid() or not is_disabled.call(index):
			return index
	return current
