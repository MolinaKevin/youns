class_name CombatMapActorTargetsPort
extends RefCounted
func sync_targets() -> void: pass
func player_target() -> Vector3: return Vector3.ZERO
func enemy_target() -> Vector3: return Vector3.ZERO
func player_rotate_speed() -> float: return 0.0
func enemy_rotate_speed() -> float: return 0.0
