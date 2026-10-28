class_name CombatMapTargetingActorHighlightsPort
extends RefCounted
func show_enemy_highlight() -> void: pass
func clear_enemy_highlight() -> void: pass
func show_self_highlight() -> void: pass
func clear_self_highlight() -> void: pass
func has_active_targeting_overlay() -> bool: return false
func has_enemy_targeting_overlay() -> bool: return false
func has_self_targeting_overlay() -> bool: return false
