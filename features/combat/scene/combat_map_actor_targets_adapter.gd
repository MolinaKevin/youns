class_name CombatMapActorTargetsAdapter
extends CombatMapActorTargetsPort
var source
func _init(value) -> void: source = value
func sync_targets() -> void: source.sync_targets()
func player_target() -> Vector3: return source.player_target()
func enemy_target() -> Vector3: return source.enemy_target()
func player_rotate_speed() -> float: return source.player_rotate_speed()
func enemy_rotate_speed() -> float: return source.enemy_rotate_speed()
