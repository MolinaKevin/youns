class_name CombatSpellSystem
extends RefCounted

## Estado y resolución de hechizos dirigidos a una zona del tablero.
## MapArea conserva las consultas espaciales y expone fachadas públicas.
const DELAYED_PUDDLE_TICK_FRACTION := 0.25

var map: CombatMapArea
var delayed_zones: Array[CombatDelayedZone] = []

func start_selection(spell_range: float) -> void:
	map.presentation.combat_preview.show_player_range(spell_range)

func clear_selection() -> void:
	map.presentation.combat_preview.hide_attack_range()
	map.selection.actions.overwatch.clear_overwatch_selection()
	map.presentation.targeting.overlay.actors.clear_enemy_highlight()

## Marca una zona que cae al terminar la ronda en la que llega a cero.
func place_delayed_zone(pos: Vector2, radius: float, damage: int, zone_name: String,
		rounds: int = 1, effect: String = "", puddle_turns: int = 0) -> void:
	var marker: MeshInstance3D = map.presentation.overlay_port.make_disc(Color(1.0, 0.25, 0.1, 0.45))
	map.presentation.overlay_port.build_tile_disc(marker, pos, radius, 0.0, map.HIGHLIGHT_Y)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.outline_size = 12
	label.position = Vector3(pos.x, 0.6, pos.y)
	map.add_child(label)
	var zone := CombatDelayedZone.new(pos, radius, damage, zone_name, rounds, effect,
		puddle_turns, marker, label)
	_update_label(zone)
	delayed_zones.append(zone)

## Pasa una ronda y devuelve las zonas que acaban de caer.
func resolve_delayed_zones() -> Array[CombatDelayedImpact]:
	var results: Array[CombatDelayedImpact] = []
	for i in range(delayed_zones.size() - 1, -1, -1):
		var zone := delayed_zones[i]
		zone.rounds -= 1
		if zone.rounds > 0:
			_update_label(zone)
			continue
		var tick := roundi(float(zone.damage) * DELAYED_PUDDLE_TICK_FRACTION)
		results.push_front(CombatDelayedImpact.new(zone.display_name, zone.damage, zone.effect, tick,
			map.queries.areas.is_enemy_in_area_circle(zone.position, zone.radius),
			map.queries.areas.is_player_in_area_circle(zone.position, zone.radius)))
		if zone.effect != "":
			var puddle_damage := tick if zone.effect in ["fire", "poison", "blood"] else 0
			map.placement.puddles.place_puddle(zone.position, zone.radius, zone.effect, zone.puddle_turns, puddle_damage)
		zone.dispose()
		delayed_zones.remove_at(i)
	return results

func _update_label(zone: CombatDelayedZone) -> void:
	if is_instance_valid(zone.label):
		zone.label.text = str(zone.rounds)
