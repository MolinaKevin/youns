class_name CombatMapActorQueriesAdapter
extends CombatMapActorQueriesPort
var source: CombatMapQueries
func _init(value: CombatMapQueries) -> void: source = value
func movement_distance(from: Vector2, to: Vector2) -> float: return source.movement_distance(from, to)
func actors_gap() -> float: return source.actors_gap()
func is_enemy_in_attack_range(attack_range: float) -> bool: return source.is_enemy_in_attack_range(attack_range)
func is_enemy_in_melee_range() -> bool: return source.is_enemy_in_melee_range()
func is_player_in_melee_range() -> bool: return source.is_player_in_melee_range()
func player_area_contact_radius() -> float: return source.player_area_contact_radius()
func enemy_area_contact_radius() -> float: return source.enemy_area_contact_radius()
