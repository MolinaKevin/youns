class_name CombatMapConstructionPort
extends RefCounted

## API usada únicamente para poblar el estado inicial de un tablero.
## Los layouts de bioma no necesitan conocer MapArea ni CombatTerrain.

func clear_obstacles() -> void: pass
func obstacles() -> Array[Dictionary]: return []
func add_solid(_pos: Vector2, _radius: float) -> void: pass
func add_solid_box(_pos: Vector2, _size: Vector2) -> void: pass
func add_rock(_pos: Vector2, _radius: float, _module: bool = true) -> void: pass
func add_bridge(_pos: Vector2, _size: Vector2) -> void: pass
func add_tree(_pos: Vector2, _radius: float = 0.6) -> void: pass
func add_platform(_pos: Vector2, _size: Vector2, _ramps: Array[Dictionary] = []) -> void: pass
