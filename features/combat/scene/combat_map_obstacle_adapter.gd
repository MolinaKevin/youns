class_name CombatMapObstacleAdapter
extends CombatMapObstaclePort

## Adaptador de obstáculos construido sobre los sistemas concretos del tablero.
## Expone sólo las consultas y acciones de obstáculos del tablero.
var _map: CombatMapArea
var _rock_jump_system: RockJumpSystem
var _module_system: ModuleSystem
var _tree_system: TreeSystem

func _init(map: CombatMapArea, rock_jump_system: RockJumpSystem, module_system: ModuleSystem, tree_system: TreeSystem) -> void:
	_map = map
	_rock_jump_system = rock_jump_system
	_module_system = module_system
	_tree_system = tree_system
	rocks = CombatMapRockAdapter.new(self)
	modules = CombatMapModuleAdapter.new(self)
	trees = CombatMapTreeAdapter.new(self)

func rocks_in_range(origin: Vector2, reach: float) -> Array[Dictionary]: return _rock_jump_system.get_rocks_in_range(origin, reach)
func rock_near(pos: Vector2) -> Dictionary: return _rock_jump_system.get_rock_near(pos)
func can_jump_land_at(pos: Vector2) -> bool: return not _map.terrain.geometry.collision.is_tile_obstructed(pos, 0)
func land_player_from_jump(pos: Vector2) -> void:
	_map.player_pos = pos
	_map.player_elevation = _map.terrain.geometry.bounds.elevation_at(pos)
	_map.actors.state.targets.sync_targets()
func is_enemy_near(pos: Vector2, radius: float) -> bool: return _rock_jump_system.is_enemy_near_pos(pos, radius)
func can_blink_to(pos: Vector2) -> bool: return _map.terrain.geometry.collision.can_blink_to(pos)
func module_at(pos: Vector2) -> Dictionary: return _module_system.get_module_at(pos)
func obstacle_gap(obstacle: Dictionary) -> float: return _module_system.obstacle_gap(obstacle)
func break_modules(obstacle: Dictionary, count: int) -> int: return _module_system.break_modules(obstacle, count)
func build_modules(pos: Vector2, count: int) -> int: return _module_system.build_modules(pos, count)
func slide_module(obstacle: Dictionary, direction: Vector2, distance: float) -> Dictionary: return _module_system.slide_module(obstacle, direction, distance)
func throw_module(obstacle: Dictionary, target: Vector2) -> Dictionary: return _module_system.throw_module(obstacle, target)
func collapse_modules_on_enemy() -> int: return _module_system.collapse_modules_on_enemy()
func modules_adjacent_to_enemy() -> Array: return _module_system.modules_adjacent_to_enemy()
func tree_at(pos: Vector2) -> Dictionary: return _tree_system.get_tree_at(pos)
func can_drop_at(pos: Vector2) -> bool: return _tree_system.can_drop_at(pos)
func is_tree_burning(tree: Dictionary) -> bool: return TreeSystem.is_tree_burning(tree)
func is_tree_near(pos: Vector2, reach: float) -> bool: return _tree_system.is_tree_near(pos, reach)
func climb_tree(tree: Dictionary, landing: Vector2) -> void: _tree_system.climb_tree(tree, landing)
func drop_from_tree(landing: Vector2) -> bool: return _tree_system.drop_from_tree(landing)
func fell_tree(tree: Dictionary, direction: Vector2) -> Dictionary: return _tree_system.fell_tree(tree, direction)
func ignite_trees_in_circle(center: Vector2, radius: float) -> int: return _tree_system.ignite_trees_in_circle(center, radius)
func ignite_trees_in_cone(origin: Vector2, direction: Vector2, reach: float, half_angle: float) -> int: return _tree_system.ignite_trees_in_cone(origin, direction, reach, half_angle)
func extinguish_trees_in_circle(center: Vector2, radius: float) -> int: return _tree_system.extinguish_trees_in_circle(center, radius)
func first_tree_on_segment(from: Vector2, to: Vector2) -> Dictionary: return _tree_system.first_tree_on_segment(from, to)
func tick_trees() -> void: _tree_system.tick_trees()
func is_player_in_tree(tree: Dictionary) -> bool: return _tree_system.is_player_in_this_tree(tree)
func player_is_in_tree() -> bool: return _tree_system.is_player_in_tree()
