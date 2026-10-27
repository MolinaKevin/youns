class_name ModalScreenContext
extends RefCounted

## Pausa/oculta el mundo para una pantalla modal. Antes este bloque se repetía,
## con variantes inconsistentes, en item_inventory_screen, deck_builder_screen,
## reincarnated_cards_screen, technical_map, laboratory (modo standalone),
## quick_menu y pause_menu.

## Pantallas standalone que reemplazan la escena entera (change_scene_to_file):
## no hace falta restaurar nada, game_world._ready() vuelve a prender todo al
## volver.
static func enter_fullscreen(host: ModalScreenHost) -> void:
	host.set_clock_visible(false)
	host.set_clock_paused(true)
	host.set_youns_status_visible(false)
	host.set_world_visible(false)
	host.set_party_visible(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## Overlays que se agregan/sacan de encima del mundo sin cambiar de escena
## (menú rápido, pausa): guardar el estado previo en enter_overlay() y
## restaurarlo simétricamente en exit_overlay(), una instancia por overlay.
var _clock_was_visible := true
var _status_was_visible := false
var _clock_was_paused := false
var _tree_was_paused := false
var _mouse_was_mode := Input.MOUSE_MODE_CAPTURED
var _host: ModalScreenHost


func _init(host: ModalScreenHost) -> void:
	_host = host

func enter_overlay(node: Node, hide_clock := false, hide_status := false, show_mouse := false) -> void:
	_clock_was_visible = _host.clock_visible()
	_status_was_visible = _host.youns_status_visible()
	_clock_was_paused = _host.clock_paused()
	_tree_was_paused = node.get_tree().paused
	_mouse_was_mode = Input.mouse_mode
	if hide_clock:
		_host.set_clock_visible(false)
	_host.set_clock_paused(true)
	if hide_status:
		_host.set_youns_status_visible(false)
	node.get_tree().paused = true
	if show_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func exit_overlay(node: Node) -> void:
	_host.set_clock_paused(_clock_was_paused)
	_host.set_clock_visible(_clock_was_visible)
	_host.set_youns_status_visible(_status_was_visible)
	node.get_tree().paused = _tree_was_paused
	Input.mouse_mode = _mouse_was_mode
