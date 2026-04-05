class_name CombatState
extends RefCounted

var player_hp := 40
var player_block := 0
var player_energy := 3
var max_energy := 3

var enemy_hp := 35
var enemy_block := 0
var enemy_intent := {"type": "attack", "value": 7}

var hand: Array = []
var draw_pile: Array = []
var discard_pile: Array = []
