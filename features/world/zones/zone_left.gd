extends Node3D

var zone_id := "left"

func _ready() -> void:
	$ZoneTrigger.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		ZoneManager.enter_zone(zone_id)
