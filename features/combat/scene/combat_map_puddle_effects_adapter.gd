class_name CombatMapPuddleEffectsAdapter
extends RefCounted

var queries: CombatMapPuddleQueriesAdapter
var mutation: CombatMapPuddleMutationAdapter
var zones: CombatMapPuddleZoneEffectsAdapter

var source
func _init(value: CombatMapEffectsPort) -> void:
	source = value
	queries = CombatMapPuddleQueriesAdapter.new(self)
	mutation = CombatMapPuddleMutationAdapter.new(self)
	zones = CombatMapPuddleZoneEffectsAdapter.new(self)
func puddle_at(pos: Vector2) -> Dictionary: return source.puddle_at(pos)
func puddles() -> Array[Dictionary]: return source.puddles()
func puddle_visual_count() -> int: return source.puddle_visual_count()
func move_puddle(zone: Dictionary, to: Vector2) -> Dictionary: return source.move_puddle(zone, to)
func convert_puddles(center: Vector2, radius: float, effects: Array, to_effect: String) -> int: return source.convert_puddles(center, radius, effects, to_effect)
func puddles_on_segment(from: Vector2, to: Vector2, effects: Array) -> Array: return source.puddles_on_segment(from, to, effects)
func puddle_damage_along(from: Vector2, to: Vector2, margin: float = 0.0) -> Dictionary: return source.puddle_damage_along(from, to, margin)
func puddle_effects_along(from: Vector2, to: Vector2, margin: float = 0.0) -> Dictionary: return source.puddle_effects_along(from, to, margin)
func zone_effects_along(from: Vector2, to: Vector2, margin: float = 0.0) -> Dictionary: return source.zone_effects_along(from, to, margin)
func tick_puddles() -> void: source.tick_puddles()
