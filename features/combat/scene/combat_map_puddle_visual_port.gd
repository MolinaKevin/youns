class_name CombatMapPuddleVisualPort
extends RefCounted

## Intenciones visuales de los charcos: construir, reconstruir y liberar los
## MeshInstance3D de cada zona. PuddleSystem pide esto sin conocer los nodos.

func show_puddle(_pos: Vector2, _radius: float, _effect: String, _exclusions: Array = []) -> MeshInstance3D:
	return null

func show_lens(_c1: Vector2, _r1: float, _c2: Vector2, _r2: float, _effect: String) -> MeshInstance3D:
	return null

func remove_visual(_mesh: MeshInstance3D) -> void:
	pass
