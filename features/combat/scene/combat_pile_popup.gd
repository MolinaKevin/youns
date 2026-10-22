class_name CombatPilePopup
extends RefCounted

## Ventana que muestra el mazo (robo o descarte) para mirarlo. `host` es el
## Combat dueño exclusivo de esta instancia.

var host: Combat
var source := ""

func _init(p_host: Combat) -> void:
	host = p_host

func show_draw_pile() -> void:
	source = "draw"
	var cards: Array[CardData] = []
	cards.assign(host.state.draw_pile)
	host.pile_popup_title.text = LocalizationState.t("combat.draw_pile", [cards.size()])
	host.pile_popup_grid.set_cards(cards)
	host.pile_popup.visible = true

func show_discard_pile() -> void:
	source = "discard"
	var cards: Array[CardData] = []
	cards.assign(host.state.discard_pile)
	host.pile_popup_title.text = LocalizationState.t("combat.discard_pile", [cards.size()])
	host.pile_popup_grid.set_cards(cards)
	host.pile_popup.visible = true

func close() -> void:
	host.pile_popup.visible = false
	source = ""
	host.turn.keep_half = {}
	host.wildcards_ui.close_keep_picker()

## Lo llama Combat._apply_localized_text() al cambiar de idioma.
func refresh_title_if_visible() -> void:
	if host.pile_popup.visible and source == "draw":
		host.pile_popup_title.text = LocalizationState.t("combat.draw_pile", [host.state.draw_pile.size()])
	elif host.pile_popup.visible and source == "discard":
		host.pile_popup_title.text = LocalizationState.t("combat.discard_pile", [host.state.discard_pile.size()])
