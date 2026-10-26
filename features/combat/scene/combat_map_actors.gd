class_name CombatMapActors
extends RefCounted

## Fachada inicial del estado físico/visual de los combatientes. Centraliza los
## radios que usan navegación, targeting y presentación sin exponerlos como un
## detalle de MapArea.
var map: MapArea
var overlay: CombatMapOverlay
var terrain: CombatMapTerrain
var mover: CombatActorMover
var trees: TreeSystem

const PLAYER_PRIORITY_ANIMATIONS: Array[String] = ["attack", "range", "damage", "die"]
const ENEMY_PRIORITY_ANIMATIONS: Array[String] = ["attack", "damage"]

var _player_radius: float = 0.4
var _enemy_radius: float = 0.4
var _player_view: CombatActorView
var _enemy_view: CombatActorView
var _player_target := Vector3.ZERO
var _enemy_target := Vector3.ZERO
var _player_rotate_speed: float = 8.0
var _enemy_rotate_speed: float = 8.0

func player_radius() -> float:
	return _player_radius

func enemy_radius() -> float:
	return _enemy_radius

func set_player_radius(radius: float) -> void:
	_player_radius = radius

func set_enemy_radius(radius: float) -> void:
	_enemy_radius = radius

func sync_targets() -> void:
	var player_y: float = terrain.player_height_at(map.player_pos, map.player_elevation)
	_player_target = Vector3(map.player_pos.x, player_y, map.player_pos.y)
	if trees.is_player_in_tree():
		var tree_pos: Vector2 = trees.climbed_tree_position()
		_player_target = Vector3(tree_pos.x, map.TREE_HEIGHT, tree_pos.y)
	var enemy_y: float = float(map.enemy_elevation) * map.PLATFORM_HEIGHT
	_enemy_target = Vector3(map.enemy_pos.x, enemy_y, map.enemy_pos.y)

func play_player_animation(animation: String) -> void:
	if _player_view != null:
		_player_view.play(animation)

func play_enemy_animation(animation: String) -> void:
	if _enemy_view != null:
		_enemy_view.play(animation)

func refresh_shadows() -> void:
	if _player_view != null:
		map.show_disc(overlay.player_shadow, Vector2(_player_view.position.x, _player_view.position.z), player_radius())
	if _enemy_view != null:
		map.show_disc(overlay.enemy_shadow, Vector2(_enemy_view.position.x, _enemy_view.position.z), enemy_radius())

func player_view() -> CombatActorView:
	return _player_view

func enemy_view() -> CombatActorView:
	return _enemy_view

func player_target() -> Vector3:
	return _player_target

func enemy_target() -> Vector3:
	return _enemy_target

func player_rotate_speed() -> float:
	return _player_rotate_speed

func enemy_rotate_speed() -> float:
	return _enemy_rotate_speed

func player_priority_animations() -> Array[String]:
	return PLAYER_PRIORITY_ANIMATIONS

func enemy_priority_animations() -> Array[String]:
	return ENEMY_PRIORITY_ANIMATIONS

func set_views(player_view: CombatActorView, enemy_view: CombatActorView) -> void:
	_player_view = player_view
	_enemy_view = enemy_view
	_player_target = Vector3(map.player_pos.x, 0.0, map.player_pos.y)
	_enemy_target = Vector3(map.enemy_pos.x, 0.0, map.enemy_pos.y)
	_player_view.position = _player_target
	_enemy_view.position = _enemy_target

func clear_player_waypoints() -> void:
	mover.clear_player_waypoints()

func add_player_waypoint(waypoint: Vector3) -> void:
	mover.add_player_waypoint(waypoint)

func has_player_waypoints() -> bool:
	return mover.has_player_waypoints()

func set_player_final_waypoint(waypoint: Vector3) -> void:
	mover.set_player_final_waypoint(waypoint)

func clear_enemy_waypoints() -> void:
	mover.clear_enemy_waypoints()

func add_enemy_waypoint(waypoint: Vector3) -> void:
	mover.add_enemy_waypoint(waypoint)

func mark_enemy_move_pending() -> void:
	mover.mark_enemy_move_pending()

func configure_player(data: YounData) -> void:
	_player_radius = data.combat_footprint_radius()
	_player_rotate_speed = data.rotate_speed
	_player_view.setup(data)

func configure_enemy(data: YounData) -> void:
	_enemy_radius = data.combat_footprint_radius()
	_enemy_rotate_speed = data.rotate_speed
	_enemy_view.setup(data)
