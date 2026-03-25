extends Resource
class_name RunStateData

@export var current_hp: int = 50
@export var max_hp: int = 50
@export var gold: int = 0

@export var deck_card_ids: Array[String] = []
@export var draw_pile_ids: Array[String] = []
@export var discard_pile_ids: Array[String] = []
@export var hand_card_ids: Array[String] = []

@export var active_relic_ids: Array[String] = []
