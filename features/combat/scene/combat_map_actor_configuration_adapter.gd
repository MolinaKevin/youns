class_name CombatMapActorConfigurationAdapter
extends CombatMapActorConfigurationPort
var source
func _init(value) -> void: source = value
func configure_player(data: YounData) -> void: source.configure_player(data)
func configure_enemy(data: YounData) -> void: source.configure_enemy(data)
