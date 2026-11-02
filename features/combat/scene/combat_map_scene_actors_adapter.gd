class_name CombatMapSceneActorsAdapter
extends RefCounted
var source
func _init(value) -> void: source = value
func setup_actors() -> void: source.setup_actors()
func setup_player(data: YounData) -> void: source.setup_player(data)
func setup_enemy(data: YounData) -> void: source.setup_enemy(data)
