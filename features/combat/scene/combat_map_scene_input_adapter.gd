class_name CombatMapSceneInputAdapter
extends CombatMapSceneInputPort

var source
func _init(value) -> void: source = value
func lock_hover_at_last_click() -> void: source.lock_hover_at_last_click()
func unlock_hover() -> void: source.unlock_hover()
func is_hover_locked() -> bool: return source.is_hover_locked()
