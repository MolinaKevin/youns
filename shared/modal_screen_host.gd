class_name ModalScreenHost
extends RefCounted

## Adaptador del runtime para una pantalla modal. ModalScreenContext depende de
## esta API, no de los autoloads concretos; cada punto de entrada provee los
## nodos de la sesión actual.

var _hud: Variant
var _game_state: Variant
var _zone_manager: Variant
var _party_manager: Variant


func _init(hud: Variant, game_state: Variant, zone_manager: Variant, party_manager: Variant) -> void:
	_hud = hud
	_game_state = game_state
	_zone_manager = zone_manager
	_party_manager = party_manager


func set_clock_visible(visible: bool) -> void: _hud.set_clock_visible(visible)
func clock_visible() -> bool: return _hud.clock_visible
func set_clock_paused(paused: bool) -> void: _hud.set_clock_paused(paused)
func clock_paused() -> bool: return _game_state.clock_paused
func set_youns_status_visible(visible: bool) -> void: _hud.set_youns_status_visible(visible)
func youns_status_visible() -> bool: return _hud.youns_status_visible
func set_world_visible(visible: bool) -> void: _zone_manager.set_world_visible(visible)
func set_party_visible(visible: bool) -> void: _party_manager.set_party_visible(visible)
