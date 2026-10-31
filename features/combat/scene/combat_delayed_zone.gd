class_name CombatDelayedZone
extends RefCounted

## Zona de un hechizo que impacta después de varias rondas. Mantenerla tipada
## evita que UI, resolución y placement dependan de las mismas claves string.

var position: Vector2
var radius: float
var damage: int
var display_name: String
var rounds: int
var effect: String
var puddle_turns: int
var marker: MeshInstance3D
var label: Label3D


func _init(p_position: Vector2, p_radius: float, p_damage: int, p_display_name: String,
		p_rounds: int, p_effect: String, p_puddle_turns: int, p_marker: MeshInstance3D,
		p_label: Label3D) -> void:
	position = p_position
	radius = p_radius
	damage = p_damage
	display_name = p_display_name
	rounds = maxi(1, p_rounds)
	effect = p_effect
	puddle_turns = p_puddle_turns
	marker = p_marker
	label = p_label


func dispose() -> void:
	if is_instance_valid(marker):
		marker.queue_free()
	if is_instance_valid(label):
		label.queue_free()
