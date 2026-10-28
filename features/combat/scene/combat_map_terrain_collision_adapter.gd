class_name CombatMapTerrainCollisionAdapter
extends CombatMapTerrainCollisionPort

var source: CombatMapTerrain
func _init(value: CombatMapTerrain) -> void: source = value
func obstacles() -> Array[Dictionary]: return source.obstacles()
func obstacle_snapshot() -> Array[Dictionary]: return source.obstacle_snapshot()
func platforms() -> Array[Dictionary]: return source.platforms()
func clip_path_at_obstacle(from: Vector2, to: Vector2) -> Vector2: return source.clip_path_at_obstacle(from, to)
func is_blocked(pos: Vector2, elevation: int = 0, margin: float = 0.5) -> bool: return source.is_blocked(pos, elevation, margin)
func is_tile_obstructed(pos: Vector2, elevation: int = 0) -> bool: return source.is_tile_obstructed(pos, elevation)
func can_blink_to(pos: Vector2) -> bool: return source.can_blink_to(pos)
