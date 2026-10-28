class_name CombatMapPushExecutionAdapter
extends CombatMapPushExecutionPort
var source
func _init(value) -> void: source = value
func push_enemy_to(landing: Vector2) -> void: source.push_enemy_to(landing)
