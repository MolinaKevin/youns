extends Resource
class_name PlayerSaveData

@export var owned_card_ids: Array[String] = []
@export var equipped_deck_ids: Array[String] = []
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
@export var needs_bathroom: bool = false
@export var bathroom_need_since_total_hour: float = -1.0
@export var last_meal_total_hour: float = -1.0
@export var hungry_since_total_hour: float = -1.0
@export var is_hungry: bool = false
@export var hungry_until_total_hour: float = -1.0
@export var bathroom_pending_after_combat: bool = false

# Hábitos activos del Youn — cada entrada tendrá un id y un porcentaje
@export var habitos: Array[Dictionary] = []

@export var unlocked_recipe_ids: Array[String] = []
@export var completed_recipe_ids: Array[String] = []
