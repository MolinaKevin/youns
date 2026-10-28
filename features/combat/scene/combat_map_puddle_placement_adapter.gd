class_name CombatMapPuddlePlacementAdapter
extends CombatMapPuddlePlacementPort
var source
func _init(value) -> void: source = value
func start_puddle_placement(reach: float, effect: String, radius: float) -> void: source.start_puddle_placement(reach, effect, radius)
func clear_puddle_placement() -> void: source.clear_puddle_placement()
func place_puddle(pos: Vector2, radius: float, effect: String = "wet", turns: int = 0, damage: int = 0) -> void: source.place_puddle(pos, radius, effect, turns, damage)
