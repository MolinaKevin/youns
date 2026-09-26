extends Node

var cards_by_id: Dictionary = {}

func _ready() -> void:
	_load_cards()

func _load_cards() -> void:
	var all_cards: Array[CardData] = [
		preload("res://data/cards/step.tres"),
		preload("res://data/cards/dash.tres"),
		preload("res://data/cards/strike.tres"),
		preload("res://data/cards/slash.tres"),
		preload("res://data/cards/block.tres"),
		preload("res://data/cards/barrera.tres"),
		preload("res://data/cards/meditar.tres"),
		preload("res://data/cards/golpe_escudo.tres"),
		preload("res://data/cards/represalia.tres"),
		preload("res://data/cards/tiron.tres"),
		preload("res://data/cards/ancla.tres"),
		preload("res://data/cards/demoler.tres"),
		preload("res://data/cards/carga_explosiva.tres"),
		preload("res://data/cards/muro.tres"),
		preload("res://data/cards/golpe_de_roca.tres"),
		preload("res://data/cards/muro_arcano.tres"),
		preload("res://data/cards/derrumbe.tres"),
		preload("res://data/cards/lanzar_roca.tres"),
		preload("res://data/cards/chispa.tres"),
		preload("res://data/cards/escarcha.tres"),
		preload("res://data/cards/descarga.tres"),
		preload("res://data/cards/aliento.tres"),
		preload("res://data/cards/nova.tres"),
		preload("res://data/cards/ceguera.tres"),
		preload("res://data/cards/lentitud.tres"),
		preload("res://data/cards/raices.tres"),
		preload("res://data/cards/curar.tres"),
		preload("res://data/cards/encantar_arma.tres"),
		preload("res://data/cards/parpadeo.tres"),
		preload("res://data/cards/traslado_charco.tres"),
		preload("res://data/cards/granizada.tres"),
		preload("res://data/cards/diluvio.tres"),
		preload("res://data/cards/lluvia_acida.tres"),
		preload("res://data/cards/trepar.tres"),
		preload("res://data/cards/meteor.tres"),
		preload("res://data/cards/arrow.tres"),
		preload("res://data/cards/snipe.tres"),
		preload("res://data/cards/grenade.tres"),
		preload("res://data/cards/bear_trap.tres"),
		preload("res://data/cards/spike_trap.tres"),
		preload("res://data/cards/salto_rupestre.tres"),
		preload("res://data/cards/envion.tres"),
		preload("res://data/cards/charco.tres"),
		preload("res://data/cards/charco_fuego.tres"),
		preload("res://data/cards/charco_grasa.tres"),
		preload("res://data/cards/enredadera.tres"),
		preload("res://data/cards/charco_sangre.tres"),
		preload("res://data/cards/charco_veneno.tres"),
		preload("res://data/cards/charco_arena.tres"),
		preload("res://data/cards/emboscada.tres"),
		preload("res://data/cards/charco_hielo.tres"),
		preload("res://data/cards/charco_planta.tres"),
		preload("res://data/cards/proyectil_hielo.tres"),
	]

	for card in all_cards:
		if card != null and card.id != "":
			cards_by_id[card.id] = card

func get_card(card_id: String) -> CardData:
	return cards_by_id.get(card_id, null)

func get_cards_from_ids(card_ids: Array[String]) -> Array[CardData]:
	var result: Array[CardData] = []

	print("CardDatabase received ids: ", card_ids)
	print("cards_by_id keys: ", cards_by_id.keys())

	for card_id in card_ids:
		var card := get_card(card_id)
		if card != null:
			result.append(card)
		else:
			push_warning("CardDatabase: card id not found -> %s" % card_id)

	return result
