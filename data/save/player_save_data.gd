extends Resource
class_name PlayerSaveData

## Se asigna al crear o migrar una partida. El valor 0 identifica partidas
## previas a que existiera el versionado.
@export var save_version: int = 0

@export var owned_card_ids: Array[String] = []
## Ids del mazo equipado. Solo sirven para armar `deck` la primera vez (ver
## DeckRules.ensure_deck): el mazo de verdad es `deck`.
@export var equipped_deck_ids: Array[String] = []
## El mazo de la partida: copias propias de las cartas (CardData.clone), así las
## evoluciones pueden recolorear mitades y agregarles líneas. Lo usan el combate
## y el armado de mazo.
@export var deck: Array[CardData] = []
@export var inventory_slots: int = 20
@export var inventory_items: Array[Dictionary] = []

@export var gold: int = 0
@export var unlocked_relic_ids: Array[String] = []
@export var player_level: int = 1
@export_range(0, 100, 1) var discipline: int = 55
@export_range(0, 100, 1) var felicidad: int = 100
@export_range(0, 10, 1) var care_mistakes: int = 0
@export var clock_ui_unlocked: bool = false
@export var care_ui_unlocked: bool = false

# Métricas ocultas — no se muestran al jugador directamente

@export_range(0, 100, 1) var confianza: int = 50
@export_range(0, 100, 1) var estres: int = 10
@export_range(0, 100, 1) var aburrimiento: int = 20
@export_range(0, 100, 1) var autocontrol: int = 50
@export_range(0, 100, 1) var energia: int = 100
@export_range(0, 100, 1) var salud: int = 100
@export var enfermo: bool = false
@export var weight: float = 10.0

# Necesidades fisiológicas
@export_range(0, 100, 1) var hambre: int = 0
@export_range(0, 100, 1) var ganas_bano: int = 0
@export var last_meal_total_hour: float = -1.0
@export var bathroom_pending_after_combat: bool = false
@export var poop_pending: float = 0.0

# Hábitos activos del Youn — cada entrada tendrá un id y un porcentaje
@export var habitos: Array[Dictionary] = []

@export var unlocked_recipe_ids: Array[String] = []
@export var completed_recipe_ids: Array[String] = []
## Mejoras permanentes obtenidas en el laboratorio.
@export var lab_youn_growth_bonus: int = 0
@export var lab_max_hp_bonus: int = 0

# Estadísticas de combate del Youn actual (ver YounStatRules). Distintas de las
# métricas de cuidado de arriba (p. ej. `energia` de cuidado ≠ "energia" de acá).
## Valor actual de cada una de las 8 estadísticas (YounStats.KEYS).
@export var youn_stats: Dictionary = {}
## Lo ganado en esta vida (registro; la evolución trabaja sobre youn_stats).
@export var youn_stat_gains: Dictionary = {}

@export_group("Estado al guardar")
## Reloj del juego (GameState.current_day / time_of_day_hours).
@export var saved_day: int = 1
@export var saved_hour: float = 8.0
@export var world_intro_seen: bool = false
## Dónde estaba el jugador: zona exterior (ZoneManager.catalog), interior (ruta de
## escena, vacío si estaba afuera) y posición.
@export var saved_zone: String = "hub"
@export var saved_interior: String = ""
@export var saved_position: Vector3 = Vector3.ZERO
@export var has_saved_position: bool = false
## Progreso del mundo: rutas, puentes y warps desbloqueados.
@export var world_progress: WorldProgressData = WorldProgressData.new()
## Estados activos del Youn (StatsManager.active_states).
@export var active_states: Dictionary = {}
## Laboratorio: lo producido sin retirar y el avance de cada receta.
@export var lab_pending_output: Dictionary = {}
@export var lab_recipe_progress: Dictionary = {}
## Receta que estaba corriendo (sigue desde su avance al cargar).
@export var lab_active_recipe_id: String = ""
@export_group("")

@export var current_youn_path: String = ""
## Evoluciones descubiertas (progreso del jugador, no del Youn): id del Youn →
## índices en su evolution_conditions de las condiciones ya reveladas. Ver
## EvolutionDiscovery.
@export var discovered_evolutions: Dictionary = {}
## Cartas reencarnadas: la que heredó cada huevo (progreso del jugador). Quedan
## para poder sumarlas a los mazos de las vidas siguientes.
@export var saved_cards: Array[CardData] = []
## Vidas del jugador: se pierde una si el Youn muere por salud (llega a 0).
## Solo se muestran en ese momento; no son una mecánica central.
@export var lives: int = 3
## El listado de cartas reencarnadas se desbloquea con la primera reencarnación.
@export var reincarnated_cards_unlocked: bool = false
@export var pending_evolution_path: String = ""
@export var stage_entered_total_hour: float = 0.0
