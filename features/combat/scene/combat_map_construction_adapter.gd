class_name CombatMapConstructionAdapter
extends CombatMapConstructionPort

const CombatObstacleScript := preload("res://features/combat/scene/combat_obstacle.gd")

var terrain: CombatTerrain

func _init(p_terrain: CombatTerrain) -> void:
	terrain = p_terrain

func clear_obstacles() -> void:
	terrain.clear()

func obstacles() -> Array[Dictionary]:
	return terrain.obstacles

func add_solid(pos: Vector2, radius: float) -> void:
	terrain.add({"pos": pos, "radius": radius, "type": CombatObstacleScript.SOLID})

func add_solid_box(pos: Vector2, size: Vector2) -> void:
	terrain.add({"pos": pos, "box": size, "type": CombatObstacleScript.SOLID})

func add_rock(pos: Vector2, radius: float, module: bool = true) -> void:
	terrain.add({"pos": pos, "radius": radius, "type": CombatObstacleScript.ROCK, "module": module})

func add_bridge(pos: Vector2, size: Vector2) -> void:
	terrain.add({"pos": pos, "box": size, "type": CombatObstacleScript.BRIDGE})

func add_tree(pos: Vector2, radius: float = 0.6) -> void:
	terrain.add({"pos": pos, "radius": radius, "type": CombatObstacleScript.TREE})

func add_platform(pos: Vector2, size: Vector2, ramps: Array[Dictionary] = []) -> void:
	terrain.add({"pos": pos, "box": size, "type": CombatObstacleScript.PLATFORM, "ramps": ramps.duplicate(true)})
