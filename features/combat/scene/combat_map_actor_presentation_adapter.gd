class_name CombatMapActorPresentationAdapter
extends CombatMapActorPresentationPort

var source: CombatMapActors
func _init(value: CombatMapActors) -> void: source = value
func play_player_animation(animation: String) -> void: source.play_player_animation(animation)
func play_enemy_animation(animation: String) -> void: source.play_enemy_animation(animation)
func refresh_shadows() -> void: source.refresh_shadows()
func player_view() -> CombatActorView: return source.player_view()
func enemy_view() -> CombatActorView: return source.enemy_view()
func player_priority_animations() -> Array[String]: return source.player_priority_animations()
func enemy_priority_animations() -> Array[String]: return source.enemy_priority_animations()
func set_views(player_view: CombatActorView, enemy_view: CombatActorView) -> void: source.set_views(player_view, enemy_view)
