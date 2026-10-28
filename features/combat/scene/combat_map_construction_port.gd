class_name CombatMapConstructionPort
extends RefCounted

## API usada únicamente para poblar el estado inicial de un tablero.
## Los layouts de bioma no necesitan conocer MapArea ni CombatTerrain.

func clear_obstacles() -> void: pass
func obstacles() -> Array[Dictionary]: return []
func add_solid(pos: Vector2, radius: float) -> void: pass
func add_solid_box(pos: Vector2, size: Vector2) -> void: pass
func add_rock(pos: Vector2, radius: float, module: bool = true) -> void: pass
func add_bridge(pos: Vector2, size: Vector2) -> void: pass
func add_tree(pos: Vector2, radius: float = 0.6) -> void: pass
func add_platform(pos: Vector2, size: Vector2, ramps: Array[Dictionary] = []) -> void: pass
