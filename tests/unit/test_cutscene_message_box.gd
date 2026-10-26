extends GutTest

const CutsceneMessageBoxScript := preload("res://features/world/reincarnation/cutscene_message_box.gd")


class MessageHost extends Node:
	var attached_panels: Array[Control] = []

	func add_message_panel(root: Control) -> void:
		add_child(root)
		attached_panels.append(root)


func test_panel_se_agrega_mediante_la_api_del_host() -> void:
	var host := MessageHost.new()
	add_child_autofree(host)
	var message_box := CutsceneMessageBoxScript.new(host)

	var parts := message_box.panel(460.0)

	assert_eq(host.attached_panels.size(), 1)
	assert_eq(host.attached_panels[0], parts[0])
	assert_eq(parts[0].get_parent(), host)
	assert_true(parts[1] is VBoxContainer)
