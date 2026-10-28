class_name CombatMapScenePresentationAdapter
extends CombatMapScenePresentationPort

var source
func _init(value) -> void: source = value
func set_status_texts(player_text: String, enemy_text: String) -> void: source.set_status_texts(player_text, enemy_text)
func place_status_labels() -> void: source.place_status_labels()
