class_name CombatMapTrapPlacementPort
extends RefCounted
func start_trap_placement(_reach: float, _radius: float = 1.0, _preview_los: bool = true) -> void: pass
func clear_trap_placement() -> void: pass
func place_trap(_pos: Vector2, _radius: float, _damage: int, _card_name: String) -> void: pass
