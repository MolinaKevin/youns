class_name MockCombatNavigation
extends RefCounted

class Terrain extends CombatMapTerrainPort:
	var owner

	class Geometry extends CombatMapTerrainGeometryPort:
		class Collision extends CombatMapTerrainCollisionPort:
			func can_blink_to(_pos: Vector2) -> bool: return true

	class Navigation extends CombatMapTerrainNavigationPort:
		func reachable_cells(_from: Vector2, _move_range: float, _elevation: int, _actor_radius: float, _blocked_by: Vector2, _blocked_radius: float) -> Array[Vector2i]: return []
		func plan_move(_pos: Vector2, _elevation: int, _actor_radius: float, _blocked_by: Vector2, _blocked_radius: float) -> String: return "no_path"

	func _init() -> void:
		geometry = Geometry.new()
		geometry.collision = Geometry.Collision.new()
		navigation = Navigation.new()

class Movement extends CombatMapMovementPort:
	var owner
	var _planned_destination := Vector2.ZERO
	func move_enemy_toward(_target: Vector2, _move_range: float) -> bool:
		owner.move_enemy_toward_calls += 1
		return true
	func plan_player_move(pos: Vector2) -> String:
		_planned_destination = pos
		return ""
	func planned_destination() -> Vector2: return _planned_destination
	func path_cost() -> float: return owner.movement_path_cost
	func try_move_player_to(pos: Vector2) -> bool:
		owner.player_pos = pos
		return true
