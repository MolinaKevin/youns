class_name CombatMapTreeAdapter
extends CombatMapTreePort

var source: CombatMapObstacleAdapter

func _init(value: CombatMapObstacleAdapter) -> void:
	source = value
	queries = CombatMapTreeQueriesAdapter.new(self)
	movement = CombatMapTreeMovementAdapter.new(self)
	effects = CombatMapTreeEffectsAdapter.new(self)
func tree_at(pos: Vector2) -> Dictionary: return source.tree_at(pos)
func can_drop_at(pos: Vector2) -> bool: return source.can_drop_at(pos)
func is_tree_burning(tree: Dictionary) -> bool: return source.is_tree_burning(tree)
func is_tree_near(pos: Vector2, reach: float) -> bool: return source.is_tree_near(pos, reach)
func climb_tree(tree: Dictionary, landing: Vector2) -> void: source.climb_tree(tree, landing)
func drop_from_tree(landing: Vector2) -> bool: return source.drop_from_tree(landing)
func fell_tree(tree: Dictionary, direction: Vector2) -> Dictionary: return source.fell_tree(tree, direction)
func ignite_trees_in_circle(center: Vector2, radius: float) -> int: return source.ignite_trees_in_circle(center, radius)
func ignite_trees_in_cone(origin: Vector2, direction: Vector2, reach: float, half_angle: float) -> int: return source.ignite_trees_in_cone(origin, direction, reach, half_angle)
func extinguish_trees_in_circle(center: Vector2, radius: float) -> int: return source.extinguish_trees_in_circle(center, radius)
func first_tree_on_segment(from: Vector2, to: Vector2) -> Dictionary: return source.first_tree_on_segment(from, to)
func tick_trees() -> void: source.tick_trees()
func is_player_in_tree(tree: Dictionary) -> bool: return source.is_player_in_tree(tree)
func player_is_in_tree() -> bool: return source.player_is_in_tree()
