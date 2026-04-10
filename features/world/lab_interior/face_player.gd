extends Node3D

func _process(_delta: float) -> void:
	var player := PartyManager.player
	if not player:
		return
	var target := player.global_position
	target.y = global_position.y
	look_at(target, Vector3.UP)
	rotate_y(PI)
