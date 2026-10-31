class_name CombatDelayedImpact
extends RefCounted

## Resultado inmutable de resolver una CombatDelayedZone. Es el contrato entre
## el tablero y el resolvedor de ronda.

var display_name: String
var damage: int
var effect: String
var tick_damage: int
var hit_enemy: bool
var hit_player: bool


func _init(p_display_name: String, p_damage: int, p_effect: String, p_tick_damage: int,
		p_hit_enemy: bool, p_hit_player: bool) -> void:
	display_name = p_display_name
	damage = p_damage
	effect = p_effect
	tick_damage = p_tick_damage
	hit_enemy = p_hit_enemy
	hit_player = p_hit_player
