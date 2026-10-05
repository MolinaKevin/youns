class_name ReincarnationRules
extends RefCounted

## Reencarnación: cuando un campeón termina su vida sin llegar a ultimate (o un
## ultimate termina la suya) muere y nace un bebé de un huevo. El Youn deja una
## carta de su mazo: el bebé nace con ella y queda guardada para siempre
## (PlayerSaveData.saved_cards) para sumarla a mazos de vidas siguientes.
##
## Lo que es del jugador sigue (oro, inventario, laboratorio, evoluciones
## descubiertas, cartas guardadas); lo que es del Youn empieza de nuevo.

## Los huevos que se muestran al reencarnar. PROVISORIO (demo): 4 huevos y solo
## el primero se puede elegir; los demás todavía no tienen bebé.
const EGGS := [
	{"youn": "res://data/youns/bebe_1.tres", "color": Color(0.95, 0.85, 0.6)},
	{"youn": "", "color": Color(0.6, 0.8, 0.95)},
	{"youn": "", "color": Color(0.75, 0.95, 0.65)},
	{"youn": "", "color": Color(0.95, 0.65, 0.75)},
]

const MAX_LIVES := 3

## Por qué muere el Youn: fin de su vida (deja una carta) o salud en 0 (no deja
## carta y el jugador pierde una vida).
const CAUSE_AGE := "age"
const CAUSE_HEALTH := "health"

## Un huevo se puede elegir si tiene un bebé que existe.
static func egg_available(egg: Dictionary) -> bool:
	var path: String = egg.get("youn", "")
	return not path.is_empty() and ResourceLoader.exists(path)

## Empieza la vida del bebé con la carta heredada (null = ninguna).
static func start_new_life(save: PlayerSaveData, baby: YounData, inherited: CardData) -> void:
	if save == null or baby == null:
		return
	save.current_youn_path = baby.resource_path
	# El bebé aparece en el árbol de evoluciones.
	var key := EvolutionDiscovery.youn_key(baby)
	if not save.discovered_evolutions.has(key):
		save.discovered_evolutions[key] = []
	save.pending_evolution_path = ""
	save.stage_entered_total_hour = GameState.get_total_hours()
	YounStatRules.start_life(save, baby)
	_reset_care(save, baby)
	var deck: Array[CardData] = []
	for card in baby.starting_deck:
		if card != null:
			deck.append(card.clone())
	if inherited != null:
		deck.append(inherited.clone())
		save.saved_cards.append(inherited.clone())
	save.deck = deck
	if inherited != null:
		save.reincarnated_cards_unlocked = true

## El cuidado vuelve a los valores base del bebé.
static func _reset_care(save: PlayerSaveData, baby: YounData) -> void:
	save.discipline = baby.base_discipline
	save.felicidad = baby.base_felicidad
	save.care_mistakes = baby.base_care_mistakes
	save.confianza = baby.base_confianza
	save.estres = baby.base_estres
	save.aburrimiento = baby.base_aburrimiento
	save.autocontrol = baby.base_autocontrol
	save.energia = 100
	save.salud = 100
	save.hambre = 0
	save.ganas_bano = 0
	save.enfermo = false
	save.weight = baby.base_weight
	save.poop_pending = 0.0
	save.last_meal_total_hour = -1.0
	save.bathroom_pending_after_combat = false
