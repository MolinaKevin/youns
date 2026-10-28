class_name CombatMapActorMovementAdapter
extends CombatMapActorMovementPort

var source: CombatMapActors
func _init(value: CombatMapActors) -> void: source = value
func clear_player_waypoints() -> void: source.clear_player_waypoints()
func add_player_waypoint(waypoint: Vector3) -> void: source.add_player_waypoint(waypoint)
func has_player_waypoints() -> bool: return source.has_player_waypoints()
func set_player_final_waypoint(waypoint: Vector3) -> void: source.set_player_final_waypoint(waypoint)
func clear_enemy_waypoints() -> void: source.clear_enemy_waypoints()
func add_enemy_waypoint(waypoint: Vector3) -> void: source.add_enemy_waypoint(waypoint)
func mark_enemy_move_pending() -> void: source.mark_enemy_move_pending()
