class_name CombatPendingAction
extends RefCounted

## Interfaz común de "hay una carta esperando que el jugador toque el mapa".
## Cada familia de carta (move, attack, grenade, trap, self, jump, push,
## module, spell, puddle, overwatch) extiende esto. CombatPlayerActions guarda
## una instancia de cada una y sólo necesita una referencia (_current_action)
## a la que esté activa, en vez de un campo pending_* por familia.

var host: CombatPlayerActions
var index: int = -1
var card: CardActionLine = null

func _init(p_host: CombatPlayerActions) -> void:
	host = p_host

## Si esto da false después de on_tile_selected()/execute(), CombatPlayerActions
## suelta _current_action — si no, el próximo click se le sigue mandando a esta
## instancia aunque ya gastó su carta (ver CombatMoveAction, que se queda
## activo con index == -1 mientras le queda rango por el reingreso).
func is_active() -> bool:
	return index >= 0

## El jugador tocó el mapa en `pos`. Cada resolver decide si eso alcanza para
## pedir confirmación (host.pending_cell + confirm_popup_show_requested) o si
## hace falta otro click más (fases).
func on_tile_selected(_pos: Vector2) -> void:
	pass

## Confirmado: ejecutar el efecto de la carta. `cell` es el último punto
## tocado (host.pending_cell); algunas familias (overwatch) ignoran el
## parámetro y usan su propio estado interno (la dirección ya calculada).
func execute(_cell: Vector2) -> void:
	pass

func clear() -> void:
	index = -1
	card = null

## Chequeo defensivo al entrar a execute(): con _current_action bien
## sincronizado (ver is_active()) no debería poder llegar acá con un índice
## inválido, pero cuesta poco cubrirse — mejor un no-op que un index out of
## bounds si algo se nos escapó.
func _index_valid() -> bool:
	return index >= 0 and index < host.state.turn_actions.size()


func _flow() -> AsyncFlowToken:
	return host.current_flow()


func _flow_is_active(flow: AsyncFlowToken) -> bool:
	return host.is_flow_active(flow)

## Chequeo combinado de flow+índice al empezar execute(): true si hay que
## cortar ahí (si es por índice inválido, ya limpió). `flow` puede ser null
## legítimamente cuando el test no conectó get_flow — null no es por sí solo
## motivo de corte, así que no se puede usar como valor de retorno "inválido".
## Lo usan las familias que necesitan el token después para un await
## (attack, spell, push, module, grenade, jump).
func _should_abort_execute(flow: AsyncFlowToken) -> bool:
	if not _flow_is_active(flow):
		return true
	if not _index_valid():
		clear()
		return true
	return false

## Solo el chequeo de índice, para las familias que no necesitan el flow
## token al empezar execute() (overwatch, self, trap, puddle).
func _require_valid_index() -> bool:
	if _index_valid():
		return true
	clear()
	return false

## Cierre de on_tile_selected() cuando el click alcanza para pedir
## confirmación: guarda la celda y pide el popup. Repetido en casi todas las
## familias (attack, spell, push, module, grenade, jump, trap, puddle).
func _request_confirm(pos: Vector2, started := false) -> void:
	host.pending_cell = pos
	host.confirm_popup_show_requested.emit(started)

## Gasta la carta jugada: sale de turn_actions, se limpia la selección propia
## de la familia (clear(), polimórfico) y se cierra la vista previa. La
## mayoría de los execute() arrancan así. grenade no lo usa porque necesita
## mantener su vista previa mientras vuela el proyectil; move no tiene este
## flujo (ver CombatMoveAction).
func _spend_card() -> void:
	host.state.turn_actions.remove_at(index)
	clear()
	# Las señales son síncronas: si el refresco de mano ocurre mientras esta
	# referencia sigue activa, CombatTurnFlow interpreta que la selección aún
	# está pendiente y no avanza a la próxima línea.
	if host.current_action() == self:
		host.clear_current_action()
	host.card_preview_hide_requested.emit()

## Cierre común a las familias que animan algo después de gastar la carta:
## refresca mano y UI, y chequea si el combate terminó.
func _finish() -> void:
	host.hand_refresh_requested.emit()
	host.ui_update_requested.emit()
	host.check_combat_end.call()
