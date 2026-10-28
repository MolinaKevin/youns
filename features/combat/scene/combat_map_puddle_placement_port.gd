class_name CombatMapPuddlePlacementPort
extends RefCounted
func start_puddle_placement(_reach: float, _effect: String, _radius: float) -> void: pass
func clear_puddle_placement() -> void: pass
func place_puddle(_pos: Vector2, _radius: float, _effect: String = "wet", _turns: int = 0, _damage: int = 0) -> void: pass
