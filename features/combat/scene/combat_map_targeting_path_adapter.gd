class_name CombatMapTargetingPathAdapter
extends CombatMapTargetingPathPort
var source
func _init(value) -> void: source = value
func show_path_preview() -> void: source.show_path_preview()
func clear_path_preview() -> void: source.clear_path_preview()
