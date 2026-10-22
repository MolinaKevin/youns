class_name GrenadeSystem
extends Node3D

## Granadas: dónde cae el tiro (rebota al azar y se frena si un obstáculo se
## cruza en el camino) y el disco de la explosión. A diferencia de los
## charcos (ver puddle_system.gd) no tiene duración ni combinación: es
## geometría pura más un disco que se prende y apaga.
##
## Vive como hijo de MapArea, que se asigna a sí mismo en `map` antes de
## agregarlo al árbol (ver MapArea._init()) — lo necesita para la malla
## compartida (_show_disc), el límite del mapa (WORLD_W/WORLD_H), el frenado
## en obstáculos (_clip_path_at_obstacle, compartido con Push) y el chequeo de
## si el enemigo queda en el área (is_enemy_in_area_circle).

## Asignado por MapArea antes de add_child(self) — ver MapArea._init().
var map: MapArea

var landing    := Vector2(-1.0, -1.0)
var aoe_radius := 0.0

var _disc: MeshInstance3D


func _ready() -> void:
	_disc = PlacementPreview.make_local_disc(self, map, Color(0.9, 0.8, 0.1, 0.45))

## Dónde cae la granada: rebote al azar según `bounce` (0 = tiro directo),
## recortado a los bordes del mapa, y se frena si un obstáculo se cruza antes.
func calculate_landing(from: Vector2, target: Vector2, bounce: float) -> Vector2:
	var result: Vector2
	if bounce == 0.0:
		result = target
	else:
		var dir := (target - from).normalized()
		result  = target + dir.rotated(randf_range(-PI / 5.0, PI / 5.0)) * bounce * 10.0
		result  = Vector2(clampf(result.x, 0.0, map.WORLD_W), clampf(result.y, 0.0, map.WORLD_H))
	return map._clip_path_at_obstacle(from, result)

func show_preview(new_landing: Vector2, radius: float) -> void:
	landing    = new_landing
	aoe_radius = float(radius)
	map._show_disc(_disc, landing, aoe_radius)

func clear_preview() -> void:
	landing       = Vector2(-1.0, -1.0)
	aoe_radius    = 0.0
	_disc.visible = false

func is_enemy_in_explosion(center: Vector2, radius: float) -> bool:
	return map.is_enemy_in_area_circle(center, radius)

## true mientras se ve el disco de la explosión (para el "any_disc" de
## MapArea._update_hover()).
func is_active() -> bool:
	return _disc.visible
