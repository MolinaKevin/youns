class_name CombatMapDelayedEffectsAdapter
extends CombatMapDelayedEffectsPort

var source
func _init(value: CombatMapEffectsPort) -> void: source = value
func place_delayed_zone(pos: Vector2, radius: float, damage: int, name: String, rounds: int = 1, effect: String = "", turns: int = 0) -> void: source.place_delayed_zone(pos, radius, damage, name, rounds, effect, turns)
func resolve_delayed_zones() -> Array: return source.resolve_delayed_zones()
func delayed_zones() -> Array[Dictionary]: return source.delayed_zones()
func blink_player_to(pos: Vector2) -> void: source.blink_player_to(pos)
