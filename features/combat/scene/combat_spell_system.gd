class_name CombatSpellSystem
extends RefCounted

## Estado y resolución de hechizos dirigidos a una zona del tablero.
## MapArea conserva las consultas espaciales y expone fachadas públicas.
const DELAYED_PUDDLE_TICK_FRACTION := 0.25

var map: MapArea
var delayed_zones: Array[Dictionary] = []

func start_selection(spell_range: float) -> void:
	map.presentation.show_player_range(spell_range)

func clear_selection() -> void:
	map.presentation.hide_attack_range()
	map.interactions.clear_overwatch_selection()
	map.presentation.clear_enemy_highlight()

## Marca una zona que cae al terminar la ronda en la que llega a cero.
func place_delayed_zone(pos: Vector2, radius: float, damage: int, zone_name: String,
		rounds: int = 1, effect: String = "", puddle_turns: int = 0) -> void:
	var marker: MeshInstance3D = map.presentation.make_disc(Color(1.0, 0.25, 0.1, 0.45))
	map.presentation.build_tile_disc(marker, pos, radius, 0.0, map.HIGHLIGHT_Y)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.outline_size = 12
	label.position = Vector3(pos.x, 0.6, pos.y)
	map.add_child(label)
	var zone: Dictionary = {
		"pos": pos, "radius": radius, "damage": damage, "name": zone_name,
		"rounds": maxi(1, rounds), "effect": effect, "puddle_turns": puddle_turns,
		"node": marker, "label": label,
	}
	_update_label(zone)
	delayed_zones.append(zone)

## Pasa una ronda y devuelve las zonas que acaban de caer.
func resolve_delayed_zones() -> Array:
	var results: Array = []
	for i in range(delayed_zones.size() - 1, -1, -1):
		var zone: Dictionary = delayed_zones[i]
		zone["rounds"] -= 1
		if zone["rounds"] > 0:
			_update_label(zone)
			continue
		var tick := roundi(float(zone["damage"]) * DELAYED_PUDDLE_TICK_FRACTION)
		results.push_front({
			"name": zone["name"], "damage": zone["damage"], "effect": zone["effect"], "tick_damage": tick,
			"enemy": map.queries.is_enemy_in_area_circle(zone["pos"], zone["radius"]),
			"player": map.queries.is_player_in_area_circle(zone["pos"], zone["radius"]),
		})
		if zone["effect"] != "":
			var puddle_damage := tick if zone["effect"] in ["fire", "poison", "blood"] else 0
			map.interactions.place_puddle(zone["pos"], zone["radius"], zone["effect"], zone["puddle_turns"], puddle_damage)
		for key in ["node", "label"]:
			var node = zone.get(key)
			if is_instance_valid(node):
				node.queue_free()
		delayed_zones.remove_at(i)
	return results

func _update_label(zone: Dictionary) -> void:
	var label = zone.get("label")
	if is_instance_valid(label):
		label.text = str(zone["rounds"])
