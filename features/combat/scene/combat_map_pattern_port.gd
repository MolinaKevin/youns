class_name CombatMapPatternPort
extends RefCounted

## Previsualización de patrones de cartas. Se mantiene separada de las demás
## operaciones de overlay para que las acciones no dependan de toda la UI.
func show_card_pattern(_pattern: CardPattern, _origin: Vector2, _direction: Vector2, _primary: float) -> void:
	pass

func clear_card_pattern() -> void:
	pass
