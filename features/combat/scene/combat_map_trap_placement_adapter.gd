class_name CombatMapTrapPlacementAdapter
extends CombatMapTrapPlacementPort
var source
func _init(value) -> void: source = value
func start_trap_placement(reach: float, radius: float = 1.0, preview_los: bool = true) -> void: source.start_trap_placement(reach, radius, preview_los)
func clear_trap_placement() -> void: source.clear_trap_placement()
func place_trap(pos: Vector2, radius: float, damage: int, card_name: String) -> void: source.place_trap(pos, radius, damage, card_name)
