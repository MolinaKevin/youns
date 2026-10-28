class_name CombatMapPresentationPort
extends RefCounted

## Intenciones visuales requeridas por la resolución de cartas. Los meshes,
## overlays y el hover pertenecen a la implementación concreta.

func show_card_pattern(_pattern: CardPattern, _origin: Vector2, _direction: Vector2, _primary: float) -> void:
	pass


func clear_card_pattern() -> void:
	pass


func show_path_preview() -> void:
	pass


func clear_path_preview() -> void:
	pass


func show_enemy_highlight() -> void:
	pass


func clear_enemy_highlight() -> void:
	pass


func show_self_highlight() -> void:
	pass


func clear_self_highlight() -> void:
	pass
