class_name NewGameDefaults
extends RefCounted

## Qué trae un jugador al arrancar partida nueva: Youn inicial, mazo, ítems,
## oro y stats base. Separado de SaveService para que el ciclo de vida de
## guardado (crear/cargar/migrar/escribir) no cargue también el balance de
## partida nueva.

const STARTING_YOUN_PATH := "res://data/youns/nguruvilu.tres"
const STARTING_OWNED_CARD_IDS: Array[String] = ["step", "dash", "strike", "slash", "block", "barrera", "meditar", "golpe_escudo", "represalia", "tiron", "ancla", "demoler", "carga_explosiva", "muro", "golpe_de_roca", "muro_arcano", "derrumbe", "lanzar_roca", "chispa", "escarcha", "descarga", "aliento", "nova", "ceguera", "lentitud", "raices", "curar", "encantar_arma", "parpadeo", "traslado_charco", "granizada", "diluvio", "lluvia_acida", "trepar", "meteor", "arrow", "snipe", "grenade", "salto_rupestre", "envion", "charco", "charco_fuego", "charco_grasa", "enredadera", "charco_sangre", "charco_veneno", "charco_arena", "emboscada"]
const STARTING_EQUIPPED_DECK_IDS: Array[String] = ["step", "step", "dash", "arrow", "arrow", "snipe", "grenade", "grenade", "charco_fuego", "charco_fuego", "nova", "nova", "aliento", "aliento", "muro", "demoler", "lanzar_roca", "golpe_de_roca", "derrumbe", "trepar"]
const STARTING_ITEM_PATHS: PackedStringArray = ["res://data/items/hierba_curativa.tres", "res://data/items/agua_de_manantial.tres", "res://data/items/unguento.tres"]
const STARTING_GOLD := 100
const STARTING_INVENTORY_SLOTS := 20
const STARTING_STATS := {
	"constitucion": 55, "mente": 45, "fuerza": 50, "resistencia": 50,
	"agilidad": 45, "tecnica": 45, "inteligencia": 45, "espiritu": 60,
}
