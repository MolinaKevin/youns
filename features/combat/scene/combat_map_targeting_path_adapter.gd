class_name CombatMapTargetingPathAdapter
extends RefCounted
var source
func _init(value = null) -> void: source = value
func show_path_preview() -> void: source.show_path_preview()
func clear_path_preview() -> void: source.clear_path_preview()
