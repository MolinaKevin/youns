class_name ModalScreenHost
extends "res://shared/modal_screen_host_port.gd"

## Adaptador del runtime para una pantalla modal. ModalScreenContext depende de
## esta API, no de los autoloads concretos; cada punto de entrada provee los
## nodos de la sesión actual.

var _hud: ModalScreenHudPort
var _world: ModalScreenWorldPort
var _party: ModalScreenPartyPort

## Composición estándar de runtime. Las pantallas no repiten la lista de
## autoloads; los tests todavía pueden construir el host con dobles propios.
static func from_runtime() -> ModalScreenHost:
	var hud := ModalScreenHudPort.Runtime.new(
		GlobalHUD.set_clock_visible,
		func() -> bool: return GlobalHUD.clock_visible,
		GlobalHUD.set_clock_paused,
		func() -> bool: return GameState.clock_paused,
		GlobalHUD.set_youns_status_visible,
		func() -> bool: return GlobalHUD.youns_status_visible
	)
	var world := ModalScreenWorldPort.Runtime.new(ZoneManager.set_world_visible)
	var party := ModalScreenPartyPort.Runtime.new(PartyManager.set_party_visible)
	return ModalScreenHost.new(hud, world, party)


func _init(hud: ModalScreenHudPort, world: ModalScreenWorldPort, party: ModalScreenPartyPort) -> void:
	_hud = hud
	_world = world
	_party = party


func set_clock_visible(visible: bool) -> void: _hud.set_clock_visible(visible)
func clock_visible() -> bool: return _hud.clock_visible()
func set_clock_paused(paused: bool) -> void: _hud.set_clock_paused(paused)
func clock_paused() -> bool: return _hud.clock_paused()
func set_youns_status_visible(visible: bool) -> void: _hud.set_youns_status_visible(visible)
func youns_status_visible() -> bool: return _hud.youns_status_visible()
func set_world_visible(visible: bool) -> void: _world.set_world_visible(visible)
func set_party_visible(visible: bool) -> void: _party.set_party_visible(visible)
