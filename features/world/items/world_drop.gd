extends Area3D

@export var item_name := "Data"
@export var gold_amount := 1

@onready var label: Label3D = $Label

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	label.text = item_name if gold_amount <= 0 else "%s +%dG" % [item_name, gold_amount]

func _on_body_entered(body: Node3D) -> void:
	if body != PartyManager.player:
		return
	if gold_amount > 0:
		GameState.player_save.gold += gold_amount
	queue_free()
