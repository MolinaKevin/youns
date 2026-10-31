class_name CombatMapDelayedEffectsPort
extends RefCounted

func place_delayed_zone(_pos: Vector2, _radius: float, _damage: int, _name: String, _rounds: int = 1, _effect: String = "", _puddle_turns: int = 0) -> void: pass
func resolve_delayed_zones() -> Array[CombatDelayedImpact]: return []
func delayed_zones() -> Array[CombatDelayedZone]: return []
func blink_player_to(_pos: Vector2) -> void: pass
