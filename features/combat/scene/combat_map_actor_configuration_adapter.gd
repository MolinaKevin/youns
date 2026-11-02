class_name CombatMapActorConfigurationAdapter
extends RefCounted
var source
func _init(value = null) -> void: source = value
func configure_player(data: YounData) -> void: source.configure_player(data)
func configure_enemy(data: YounData) -> void: source.configure_enemy(data)
