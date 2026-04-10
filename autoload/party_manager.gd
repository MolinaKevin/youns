extends Node

const PARTY_SCENE := preload("res://features/world/party/party.tscn")

var player: CharacterBody3D
var youn: CharacterBody3D
var camera_rig: Node3D
var next_spawn := "SpawnPoint"

func _ready() -> void:
	var party := PARTY_SCENE.instantiate()
	add_child(party)
	player = party.get_node("Player")
	youn   = party.get_node("Youn")
	camera_rig = party.get_node("CameraRig")

func place_at_spawn(scene: Node) -> void:
	var spawn := scene.get_node_or_null(next_spawn)
	next_spawn = "SpawnPoint"
	if not spawn:
		return
	var pos := (spawn as Node3D).global_position
	player.global_position = pos
	player.velocity = Vector3.ZERO
	youn.global_position = pos + Vector3(1.5, 0, 1.5)
	youn.velocity = Vector3.ZERO

func set_party_visible(visible: bool) -> void:
	for child in get_children():
		if child is Node3D:
			(child as Node3D).visible = visible
	player.set_physics_process(visible)
	youn.set_physics_process(visible)
	if camera_rig:
		camera_rig.enabled = visible
