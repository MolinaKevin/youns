class_name YounAnimBodies
extends RefCounted

## Cuerpos 3D de un Youn por nombre de animación ("idle", "walk", ...), con
## cuál está visible/reproduciendo ahora. Comparten esta lógica
## YounAppearance (compañero, un cuerpo por acción: idle/walk/run/attack/...)
## y WorldYounAppearance (NPC salvaje, solo idle/walk/run).

var _bodies: Dictionary = {}
var _current: String = ""

func register(key: String, body: Node3D) -> void:
	_bodies[key] = body

func is_empty() -> bool:
	return _bodies.is_empty()

func keys() -> Array:
	return _bodies.keys()

func current() -> String:
	return _current

## Libera todos los cuerpos y vacía el estado, antes de cargar un modelo nuevo.
func clear() -> void:
	for body in _bodies.values():
		body.queue_free()
	_bodies.clear()
	_current = ""

func switch_to(key: String) -> void:
	var target := key if key in _bodies else "idle"
	if _current == target:
		return
	if _current in _bodies:
		_bodies[_current].visible = false
	_current = target
	if target not in _bodies:
		return
	var body: Node3D = _bodies[target]
	body.visible = true
	var anim_player := Node3DSearch.find_anim_player(body)
	if anim_player == null:
		return
	var list := anim_player.get_animation_list()
	if list.is_empty():
		return
	var anim := anim_player.get_animation(list[0])
	if anim != null:
		anim.loop_mode = Animation.LOOP_LINEAR
	anim_player.play(list[0])
