class_name MockCombatObstacles
extends CombatMapObstaclePort

var owner

func rocks_in_range(_origin: Vector2, _reach: float) -> Array[Dictionary]: return [{"pos": Vector2(5.0, 0.0)}]
func rock_near(pos: Vector2) -> Dictionary: return {"pos": pos}
func can_jump_land_at(_pos: Vector2) -> bool: return true
func land_player_from_jump(pos: Vector2) -> void: owner.player_pos = pos
func is_enemy_near(pos: Vector2, radius: float) -> bool: return pos.distance_to(owner.enemy_pos) <= radius
func can_blink_to(_pos: Vector2) -> bool: return true
func module_at(_pos: Vector2) -> Dictionary: return {}
func obstacle_gap(_obs: Dictionary) -> float: return 0.0
func break_modules(obs: Dictionary, count: int) -> int:
	owner.break_modules_calls.append({"obs": obs, "count": count})
	return count
func build_modules(pos: Vector2, count: int) -> int:
	owner.build_modules_calls.append({"pos": pos, "count": count})
	return count
func slide_module(_obs: Dictionary, _direction: Vector2, _distance: float) -> Dictionary: return {"hit": "", "tree": {}}
func throw_module(_obs: Dictionary, _target: Vector2) -> Dictionary: return {"enemy": false, "player": false}
func collapse_modules_on_enemy() -> int: return 0
func modules_adjacent_to_enemy() -> Array: return []
func tree_at(_pos: Vector2) -> Dictionary: return {}
func can_drop_at(_pos: Vector2) -> bool: return true
func is_tree_burning(_tree: Dictionary) -> bool: return false
func is_tree_near(_pos: Vector2, _reach: float) -> bool: return false
func climb_tree(_tree: Dictionary, _landing: Vector2) -> void: pass
func drop_from_tree(_landing: Vector2) -> bool: return false
func fell_tree(tree: Dictionary, _direction: Vector2) -> Dictionary: return tree
func ignite_trees_in_circle(_center: Vector2, _radius: float) -> int: return 0
func ignite_trees_in_cone(_origin: Vector2, _direction: Vector2, _reach: float, _angle: float) -> int: return 0
func extinguish_trees_in_circle(_center: Vector2, _radius: float) -> int: return 0
func first_tree_on_segment(_from: Vector2, _to: Vector2) -> Dictionary: return {}
func tick_trees() -> void: pass
func is_player_in_tree(_tree: Dictionary) -> bool: return false
func player_is_in_tree() -> bool: return false
