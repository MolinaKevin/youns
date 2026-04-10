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
@export_range(0, 10, 1) var care_mistakes: int = 1
@export var clock_ui_unlocked: bool = false
@export var care_ui_unlocked: bool = false

@export var unlocked_recipe_ids: Array[String] = []
@export var completed_recipe_ids: Array[String] = []
