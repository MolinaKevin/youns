extends Button

var card_data: CardData

@onready var art = $MarginContainer/VBoxContainer/TextureRect
@onready var name_label = $MarginContainer/VBoxContainer/NameLabel
@onready var cost_label = $MarginContainer/VBoxContainer/CostLabel
@onready var type_label = $MarginContainer/VBoxContainer/TypeLabel

func _ready() -> void:
	custom_minimum_size = Vector2(180, 260)

func set_card(data: CardData) -> void:
	card_data = data

	if card_data == null:
		name_label.text = "NULL"
		cost_label.text = ""
		type_label.text = ""
		art.texture = null
		return

	name_label.text = card_data.name
	cost_label.text = "Cost: %d" % card_data.cost
	type_label.text = "Type: %s" % card_data.card_type
	art.texture = card_data.image
