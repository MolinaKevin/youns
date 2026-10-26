class_name ModalScreenContext
extends RefCounted

## Pausa/oculta el mundo para una pantalla modal. Antes este bloque se repetía,
## con variantes inconsistentes, en item_inventory_screen, deck_builder_screen,
## reincarnated_cards_screen, technical_map, laboratory (modo standalone),
## quick_menu y pause_menu.

## Pantallas standalone que reemplazan la escena entera (change_scene_to_file):
## no hace falta restaurar nada, game_world._ready() vuelve a prender todo al
## volver.
static func enter_fullscreen() -> void:
	GlobalHUD.set_clock_visible(false)
	GlobalHUD.set_clock_paused(true)
	GlobalHUD.set_youns_status_visible(false)
	ZoneManager.set_world_visible(false)
	PartyManager.set_party_visible(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## Overlays que se agregan/sacan de encima del mundo sin cambiar de escena
## (menú rápido, pausa): guardar el estado previo en enter_overlay() y
## restaurarlo simétricamente en exit_overlay(), una instancia por overlay.
var _clock_was_visible := true
var _status_was_visible := false
var _clock_was_paused := false
var _tree_was_paused := false

func enter_overlay(node: Node, hide_clock := false, hide_status := false) -> void:
	_clock_was_visible = GlobalHUD.clock_visible
	_status_was_visible = GlobalHUD.youns_status_visible
	_clock_was_paused = GameState.clock_paused
	_tree_was_paused = node.get_tree().paused
	if hide_clock:
		GlobalHUD.set_clock_visible(false)
	GlobalHUD.set_clock_paused(true)
	if hide_status:
		GlobalHUD.set_youns_status_visible(false)
	node.get_tree().paused = true

func exit_overlay(node: Node) -> void:
	GlobalHUD.set_clock_paused(_clock_was_paused)
	GlobalHUD.set_clock_visible(_clock_was_visible)
	GlobalHUD.set_youns_status_visible(_status_was_visible)
	node.get_tree().paused = _tree_was_paused
