class_name LaboratoryEchoes
extends RefCounted

## Ecos para el depósito del laboratorio. Combate es quien va contando, carta
## por carta jugada, qué Ecos se ganaron (ver CombatState.echoes_earned); acá
## solo vive qué Eco le corresponde a cada mitad y cómo se acredita el total
## al depósito al terminar la pelea. `host` es LaboratoryState (autoload, sin
## class_name) — necesita `_add_output_item()` para sumarlos al depósito.

var host

func _init(p_host) -> void:
	host = p_host

## Ids de Eco que da una carta (uno por inteligencia distinta entre sus dos
## mitades; si las dos son la misma inteligencia, da un solo Eco).
static func echo_ids_for_card(card: CardData) -> Array[String]:
	var echo_ids: Array[String] = []
	if card == null:
		return echo_ids
	for action: CardAction in [card.top, card.bottom]:
		if action == null:
			continue
		var echo_id: String = "eco_" + action.intelligence
		if echo_id not in echo_ids:
			echo_ids.append(echo_id)
	return echo_ids

## Acredita al depósito los Ecos juntados en un combate: {echo_id: cantidad}.
func deposit(counts: Dictionary) -> void:
	for echo_id in counts:
		var amount: int = counts[echo_id]
		if amount <= 0:
			continue
		host._add_output_item(echo_id, LocalizationState.item_name(echo_id, echo_id), amount, 999)
