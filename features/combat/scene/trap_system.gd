class_name TrapSystem
extends Node3D

## Trampas del combate: colocarlas y que salten cuando algo pasa cerca. A
## diferencia de los charcos (ver puddle_system.gd) no tienen tipo de efecto
## ni duración, no se combinan entre sí, y son de un solo uso: en cuanto algo
## las toca, hacen daño y desaparecen.
##
## Vive como hijo de MapArea, que se asigna a sí mismo en `map` antes de
## agregarlo al árbol (ver MapArea._init()) — lo necesita para las mallas
## compartidas (_make_mat, _build_tile_disc, _show_disc_with_los,
## _tile_in_obstacle, movement_distance).

## Asignado por MapArea antes de add_child(self) — ver MapArea._init().
var map: MapArea

var zones: Array = []
var _visuals: Array = []
var _range := 0.0

var _disc:             MeshInstance3D
var _preview:          MeshInstance3D
var _preview_radius:   float   = 1.0
var _preview_last_pos: Vector2 = Vector2(-999.0, -999.0)


func _ready() -> void:
	_disc = PlacementPreview.make_local_disc(self, map, Color(0.75, 0.4, 0.75, 0.35))
	_preview = MeshInstance3D.new()
	_preview.visible = false
	add_child(_preview)

## true mientras se está por tirar una trampa (para el "any_disc" de
## MapArea._update_hover()).
func is_placing() -> bool:
	return _disc.visible

func start_trap_placement(trap_range: float, trap_radius: float = 1.0) -> void:
	_range            = trap_range
	_preview_radius   = trap_radius
	_preview_last_pos = Vector2(-999.0, -999.0)
	_preview.visible  = false
	map._show_disc_with_los(_disc, map.player_pos, trap_range, map.player_elevation)

func clear_trap_placement() -> void:
	_range            = 0.0
	_disc.visible     = false
	_preview.visible  = false
	_preview_last_pos = Vector2(-999.0, -999.0)

## Actualiza el preview del tile bajo el mouse mientras se apunta; lo llama
## MapArea._update_hover() con la posición en el mundo ya calculada.
func update_hover_preview(pos: Vector2) -> void:
	_preview_last_pos = PlacementPreview.update_hover_preview(
		map, _disc, _preview, pos, _range, _preview_radius, _preview_last_pos,
		Color(0.8, 0.2, 0.8, 0.22), Color(1.0, 0.5, 1.0, 0.60))

func place_trap(pos: Vector2, radius: float, damage: int, card_name: String) -> void:
	zones.append({"pos": pos, "radius": float(radius), "damage": damage, "name": card_name})
	_add_trap_visual(pos, float(radius))

func _add_trap_visual(pos: Vector2, radius: float) -> void:
	var mi := MeshInstance3D.new()
	mi.set_meta("fill_mat", map._make_mat(Color(0.8, 0.2, 0.8, 0.25)))
	mi.set_meta("bord_mat", map._make_mat(Color(1.0, 0.5, 1.0, 0.70)))
	add_child(mi)
	map._build_tile_disc(mi, pos, radius, 0.0, 0.015)
	_visuals.append(mi)

func check_and_trigger_traps(unit_pos: Vector2, contact_margin: float = 0.0) -> int:
	var total := 0
	var triggered: Array = []
	for trap in zones:
		if map.movement_distance(trap["pos"], unit_pos) <= trap["radius"] + contact_margin:
			total += trap["damage"]
			triggered.append(trap)
	for t in triggered:
		var idx := zones.find(t)
		if idx >= 0 and idx < _visuals.size():
			_visuals[idx].queue_free()
			_visuals.remove_at(idx)
		zones.erase(t)
	return total

func check_and_trigger_traps_along_path(_from: Vector2, to: Vector2, contact_margin: float = 0.0) -> int:
	return check_and_trigger_traps(to, contact_margin)

func check_traps_along_segment(from: Vector2, to: Vector2, contact_margin: float = 0.0) -> int:
	var total := 0
	var triggered: Array = []
	for trap in zones:
		if CombatMapQueries.segment_point_distance(from, to, trap["pos"]) <= trap["radius"] + contact_margin:
			total += trap["damage"]
			triggered.append(trap)
	for trap in triggered:
		var idx: int = zones.find(trap)
		if idx >= 0 and idx < _visuals.size():
			_visuals[idx].queue_free()
			_visuals.remove_at(idx)
		zones.erase(trap)
	return total
