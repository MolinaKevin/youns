extends Node3D

# Sobreescribir en cada zona
var zone_id := ""

func _ready() -> void:
	$ZoneTrigger.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		ZoneManager.enter_zone(zone_id)
