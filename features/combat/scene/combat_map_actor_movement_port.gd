class_name CombatMapActorMovementPort
extends RefCounted

func clear_player_waypoints() -> void: pass
func add_player_waypoint(_waypoint: Vector3) -> void: pass
func has_player_waypoints() -> bool: return false
func set_player_final_waypoint(_waypoint: Vector3) -> void: pass
func clear_enemy_waypoints() -> void: pass
func add_enemy_waypoint(_waypoint: Vector3) -> void: pass
func mark_enemy_move_pending() -> void: pass
