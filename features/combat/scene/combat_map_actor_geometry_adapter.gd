class_name CombatMapActorGeometryAdapter
extends RefCounted
var source
func _init(value = null) -> void: source = value
func player_radius() -> float: return source.player_radius()
func enemy_radius() -> float: return source.enemy_radius()
func set_player_radius(value: float) -> void: source.set_player_radius(value)
func set_enemy_radius(value: float) -> void: source.set_enemy_radius(value)
