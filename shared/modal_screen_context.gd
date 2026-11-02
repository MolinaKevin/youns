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
## (menú rápido, pausa): WorldTransitionLease hace el snapshot/restore real;
## esto solo lo parametriza con las opciones que un overlay necesita (nunca
## congela party/cámara ni oculta el mundo, a diferencia de otros usos del
## lease).
var _host: ModalScreenHostPort
var _lease: WorldTransitionLease


func _init(host: ModalScreenHostPort) -> void:
	_host = host

func enter_overlay(_node: Node, hide_clock := false, hide_status := false, show_mouse := false) -> void:
	_lease = WorldTransitionLease.new(_host, PartyManager, {
		"freeze_actors": false,
		"freeze_camera": false,
		"pause_tree": true,
		"hide_clock": hide_clock,
		"hide_status": hide_status,
		"show_mouse": show_mouse,
	})

func exit_overlay(_node: Node) -> void:
	if _lease:
		_lease.release()
