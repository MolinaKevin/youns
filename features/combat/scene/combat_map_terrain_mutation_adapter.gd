class_name CombatMapTerrainMutationAdapter
extends RefCounted

var source: CombatMapTerrain
func _init(value: CombatMapTerrain = null) -> void: source = value
func add_obstacle(obstacle: Dictionary) -> void: source.add_obstacle(obstacle)
func remove_obstacle(obstacle: Dictionary) -> void: source.remove_obstacle(obstacle)
func obstacles_changed() -> void: source.obstacles_changed()
func warm_caches(first_radius: float, second_radius: float) -> void: source.warm_caches(first_radius, second_radius)
