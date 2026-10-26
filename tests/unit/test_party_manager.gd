extends GutTest

const PartyManagerScript := preload("res://autoload/party_manager.gd")


func _party_with_members() -> Node3D:
	var party := Node3D.new()
	var player := CharacterBody3D.new()
	player.name = "Player"
	party.add_child(player)
	var youn := CharacterBody3D.new()
	youn.name = "Youn"
	party.add_child(youn)
	var camera_rig := Node3D.new()
	camera_rig.name = "CameraRig"
	party.add_child(camera_rig)
	add_child_autofree(party)
	return party


func test_resuelve_los_tres_miembros_del_grupo() -> void:
	var party := _party_with_members()
	var members := PartyManagerScript.resolve_party_members(party)

	assert_eq(members["player"], party.get_node("Player"))
	assert_eq(members["youn"], party.get_node("Youn"))
	assert_eq(members["camera_rig"], party.get_node("CameraRig"))


func test_rechaza_un_grupo_incompleto() -> void:
	var party := Node3D.new()
	add_child_autofree(party)
	var player := CharacterBody3D.new()
	player.name = "Player"
	party.add_child(player)

	assert_true(PartyManagerScript.resolve_party_members(party).is_empty())


func test_rechaza_nodos_con_tipo_incorrecto() -> void:
	var party := Node3D.new()
	add_child_autofree(party)
	for name in ["Player", "Youn", "CameraRig"]:
		var node := Node.new()
		node.name = name
		party.add_child(node)

	assert_true(PartyManagerScript.resolve_party_members(party).is_empty())
