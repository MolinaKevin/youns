class_name CombatWildcards
extends RefCounted

const InventoryService := preload("res://shared/inventory_service.gd")

## Qué hace cada comodín (Ataque/Mover/Mantener/Ítem) cuando se arma o se
## usa. `combat_wildcards_ui.gd` es la contraparte visual del widget; esta
## clase es la lógica de juego. `host` es el Combat dueño exclusivo de esta
## instancia.

var host: Combat

func _init(p_host: Combat) -> void:
	host = p_host

func apply_localization() -> void:
	host.wildcards_ui.apply_localization(host.WILD_ATTACK, host.WILD_MOVE)

func on_toggled(wild: CombatTurnController.Wild, pressed: bool) -> void:
	if pressed:
		host.turn.armed_wild = wild
		host.log_message(LocalizationState.t("combat.wild_armed"))
	elif host.turn.armed_wild == wild:
		host.turn.armed_wild = CombatTurnController.Wild.NONE
	host.refresh_hand()

func disarm() -> void:
	host.turn.armed_wild = CombatTurnController.Wild.NONE
	host.wildcards_ui.disarm()

## Cada comodín se habilita solo si queda una mitad del tipo que reemplaza.
func update_buttons() -> void:
	var turn := host.turn
	var busy: bool = turn.playing != null and turn.playing.started
	var usable := {
		CombatTurnController.Wild.ATTACK: turn.used_top == -1 and not busy,
		CombatTurnController.Wild.MOVE: turn.used_bottom == -1 and not busy,
		CombatTurnController.Wild.KEEP: (turn.used_top == -1 or turn.used_bottom == -1) and not busy and not _keep_candidates().is_empty(),
		CombatTurnController.Wild.ITEM: (turn.used_top == -1 or turn.used_bottom == -1) and not busy and not _combat_items().is_empty(),
	}
	if host.wildcards_ui.update_state(turn.phase == CombatTurnController.Phase.ACTING, turn.armed_wild, usable, turn.playing, turn.used_top != -1 and turn.used_bottom != -1):
		disarm()

## Cartas de la mano que se pueden mantener: las que no se juegan este turno.
func _keep_candidates() -> Array[int]:
	var result: Array[int] = []
	for i in host.state.hand.size():
		if not host.turn.turn_hand_indices.has(i) and not host.turn.kept_indices.has(i):
			result.append(i)
	return result

func start_keep(card_index: int, is_top: bool) -> void:
	if host.player_actions.has_pending_selection():
		host.player_actions.cancel_selection()
	host.turn.keep_half = {"card": card_index, "is_top": is_top}
	host._pile_popup.source = ""
	var cards: Array[CardData] = []
	for i in _keep_candidates():
		cards.append(host.state.hand[i])
	host.wildcards_ui.show_keep_picker(cards)

func on_pile_card_selected(card: CardData) -> void:
	if host.turn.keep_half.is_empty():
		return
	for i in _keep_candidates():
		if host.state.hand[i] == card:
			host.turn.kept_indices.append(i)
			break
	if host.turn.keep_half["is_top"]:
		host.turn.used_top = host.turn.keep_half["card"]
	else:
		host.turn.used_bottom = host.turn.keep_half["card"]
	host.log_message(LocalizationState.t("combat.kept", [LocalizationState.card_name(card.id, card.name)]))
	host._pile_popup.close()
	disarm()
	host.refresh_hand()

## Ítems del inventario que se pueden usar en combate: [{"index", "data", "count"}].
func _combat_items() -> Array:
	var result := []
	var save: PlayerSaveData = GameState.player_save
	if save == null:
		return result
	for i in save.inventory_items.size():
		var entry: Dictionary = save.inventory_items[i]
		var path: String = entry.get("data_path", "")
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var data := load(path) as ItemData
		if data != null and data.is_combat_item():
			result.append({"index": i, "data": data, "count": int(entry.get("count", 1))})
	return result

func start_item(card_index: int, is_top: bool) -> void:
	if host.player_actions.has_pending_selection():
		host.player_actions.cancel_selection()
	host.turn.item_half = {"card": card_index, "is_top": is_top}
	host.wildcards_ui.show_item_picker(_combat_items())

func close_item_picker() -> void:
	host.turn.item_half = {}
	host.wildcards_ui.close_item_picker()

## Usa el ítem: aplica su efecto al combate, lo saca del inventario y gasta la
## mitad elegida.
func use_item(inventory_index: int, data: ItemData) -> void:
	if host.turn.item_half.is_empty():
		return
	var result := data.apply_in_combat(host.state)
	_consume_inventory_item(inventory_index)
	var parts: PackedStringArray = []
	if result.get("healed", 0) > 0:
		parts.append(LocalizationState.t("combat.item_healed", [result["healed"]]))
	if result.get("mp", 0) > 0:
		parts.append(LocalizationState.t("combat.item_mp", [result["mp"]]))
	if result.get("cleansed", false):
		parts.append(LocalizationState.t("combat.item_cleansed"))
	host.log_message(LocalizationState.t("combat.item_used", [LocalizationState.item_name(data.id, data.name)])
		+ (" " + ", ".join(parts) + "." if not parts.is_empty() else ""))
	if host.turn.item_half["is_top"]:
		host.turn.used_top = host.turn.item_half["card"]
	else:
		host.turn.used_bottom = host.turn.item_half["card"]
	close_item_picker()
	disarm()
	host.update_ui()
	host.refresh_hand()

func _consume_inventory_item(index: int) -> void:
	var items: Array = GameState.player_save.inventory_items
	InventoryService.consume_at(items, index)
	GameState.player_save.inventory_items = items
