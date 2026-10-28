class_name CombatMapActorPresentationPort
extends RefCounted

func play_player_animation(_animation: String) -> void: pass
func play_enemy_animation(_animation: String) -> void: pass
func refresh_shadows() -> void: pass
func player_view() -> CombatActorView: return null
func enemy_view() -> CombatActorView: return null
func player_priority_animations() -> Array[String]: return []
func enemy_priority_animations() -> Array[String]: return []
func set_views(_player_view: CombatActorView, _enemy_view: CombatActorView) -> void: pass
