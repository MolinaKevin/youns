class_name CombatMapTargetingActorHighlightsAdapter
extends RefCounted
var source
func _init(value = null) -> void: source = value
func show_enemy_highlight() -> void: source.show_enemy_highlight()
func clear_enemy_highlight() -> void: source.clear_enemy_highlight()
func show_self_highlight() -> void: source.show_self_highlight()
func clear_self_highlight() -> void: source.clear_self_highlight()
func has_active_targeting_overlay() -> bool: return source.has_active_targeting_overlay()
func has_enemy_targeting_overlay() -> bool: return source.has_enemy_targeting_overlay()
func has_self_targeting_overlay() -> bool: return source.has_self_targeting_overlay()
