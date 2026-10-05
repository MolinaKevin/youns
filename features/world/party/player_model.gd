extends Node3D

## Modelo del personaje principal (assets/player/pc_mesh.fbx) con sus
## animaciones (assets/player/player_animations.tres, armadas por
## tools/import_player_model.gd). El origen está a la altura de los pies y
## mira hacia +Z.
##
## Animaciones: idle, walk, run (en bucle); interact, item_give, pickup_floor,
## pickup_waist, happy, talk (en bucle), angry, think.

const MATERIAL := preload("res://assets/player/player_material.tres")
const BLEND_TIME := 0.2

@onready var _anim: AnimationPlayer = $AnimationPlayer

## Animación que vuelve a sonar al terminar una que no es en bucle.
var _base := "idle"


func _ready() -> void:
	for mesh in find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = MATERIAL
	_anim.animation_finished.connect(_on_animation_finished)
	_anim.play("player/idle")


## Animación de base (idle, walk, run): la que queda sonando.
func set_base(anim_name: String) -> void:
	if anim_name == _base:
		return
	_base = anim_name
	if not _is_playing_action():
		_anim.play("player/" + anim_name, BLEND_TIME)


## Animación de una vez (happy, interact, item_give…); al terminar vuelve a
## la de base. Devuelve cuánto dura (una vuelta, si es en bucle como talk).
func play_action(anim_name: String) -> float:
	_anim.play("player/" + anim_name, BLEND_TIME)
	return _anim.get_animation("player/" + anim_name).length


## Corta la acción (sirve para las que son en bucle) y vuelve a la de base.
func stop_action() -> void:
	_anim.play("player/" + _base, BLEND_TIME)


func get_current_animation() -> String:
	return _anim.current_animation.trim_prefix("player/")


func _is_playing_action() -> bool:
	return get_current_animation() not in ["idle", "walk", "run"]


func _on_animation_finished(_anim_name: StringName) -> void:
	_anim.play("player/" + _base, BLEND_TIME)
