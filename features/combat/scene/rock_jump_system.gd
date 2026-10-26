class_name RockJumpSystem
extends Node3D

const CombatObstacle := preload("res://features/combat/scene/combat_obstacle.gd")

## Salto de roca en roca: elegir una piedra al alcance y después dónde cae el
## salto desde ahí. Dos pasos, cada uno con su propio disco (alcance de
## piedras, alcance de aterrizaje) más los marcadores de las piedras
## elegibles y el de la piedra elegida.
##
## Vive como hijo de MapArea, que se asigna a sí mismo en `map` antes de
## agregarlo al árbol (ver MapArea._init()) — lo necesita para la lista de
## obstáculos (solid_obstacles, is_module) y las mallas compartidas
## (make_disc, build_tile_disc, make_mat).

## Asignado por MapArea antes de add_child(self) — ver MapArea._init().
var map: MapArea

var _rocks_in_range: Array[Dictionary] = []
var _rock_markers:   Array[MeshInstance3D] = []
var _selected_marker: MeshInstance3D

var _disc:         MeshInstance3D
var _landing_disc: MeshInstance3D


func _ready() -> void:
	_disc         = PlacementPreview.make_local_disc(self, map, Color(0.3, 0.9, 0.4, 0.35))
	_landing_disc = PlacementPreview.make_local_disc(self, map, Color(0.95, 0.5, 0.1, 0.40))
	# Como _make_highlight_disc: la piedra elegida se pinta más opaca y brillante
	# que un disco normal, para que se note en medio de todo lo demás resaltado.
	const MARKER_COLOR := Color(0.9, 1.0, 0.2)
	_selected_marker = PlacementPreview.make_local_disc(self, map, MARKER_COLOR)
	_selected_marker.set_meta("fill_mat", map.presentation.make_material(Color(MARKER_COLOR, 0.85)))
	_selected_marker.set_meta("bord_mat", map.presentation.make_material(Color(MARKER_COLOR.lightened(0.45), 1.0)))

func get_rocks_in_range(origin: Vector2, max_range: float) -> Array[Dictionary]:
	var rocks: Array[Dictionary] = []
	for obs in map.terrain.obstacles():
		if CombatObstacle.type_of(obs) != CombatObstacle.ROCK and not MapArea.is_module(obs):
			continue
		if origin.distance_to(obs["pos"]) <= max_range:
			rocks.append(obs)
	return rocks

func start_rock_jump_selection(jump_range: float) -> void:
	map.presentation.show_disc(_disc, map.player_pos, jump_range)
	_rocks_in_range = get_rocks_in_range(map.player_pos, jump_range)
	for obs in _rocks_in_range:
		var mi := map.presentation.make_disc(Color(0.2, 1.0, 0.5, 0.75))
		map.presentation.build_tile_disc(mi, obs["pos"], obs.get("radius", 0.5) * 1.8, 0.0, map.HIGHLIGHT_Y)
		_rock_markers.append(mi)

func get_rock_near(pos: Vector2) -> Dictionary:
	for obs in _rocks_in_range:
		var r: float = obs.get("radius", 0.5)
		if pos.distance_to(obs["pos"]) <= r + 1.5:
			return obs
	return {}

func start_jump_landing_selection(rock_pos: Vector2, landing_range: float) -> void:
	_disc.visible = false
	for marker in _rock_markers:
		marker.queue_free()
	_rock_markers.clear()
	map.presentation.show_disc(_landing_disc, rock_pos, landing_range)
	map.presentation.build_tile_disc(_selected_marker, rock_pos, 0.7, 0.0, map.HOVER_Y)

func clear_rock_jump_selection() -> void:
	_disc.visible            = false
	_landing_disc.visible    = false
	_selected_marker.visible = false
	for marker in _rock_markers:
		marker.queue_free()
	_rock_markers.clear()
	_rocks_in_range.clear()

func is_enemy_near_pos(pos: Vector2, radius: float) -> bool:
	return pos.distance_to(map.enemy_pos) <= radius

## true mientras se ve alguno de los dos discos (para el "any_disc" de
## MapArea._update_hover()).
func is_active() -> bool:
	return _disc.visible or _landing_disc.visible
