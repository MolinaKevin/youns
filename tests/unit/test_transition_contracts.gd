extends GutTest

const AsyncFlowTokenScript := preload("res://shared/async_flow_token.gd")
const WorldTransitionLeaseScript := preload("res://shared/world_transition_lease.gd")


class FakeHud extends RefCounted:
	var paused := false
	var clock_visible := true
	var status_visible := true

	func clock_paused() -> bool: return paused
	func set_clock_paused(value: bool) -> void: paused = value
	func set_clock_visible(value: bool) -> void: clock_visible = value
	func set_youns_status_visible(value: bool) -> void: status_visible = value
	func youns_status_visible() -> bool: return status_visible


class FakeCamera extends Node:
	var enabled := true


class FakeParty extends Node:
	var player := Node.new()
	var youn := Node.new()
	var camera_rig := FakeCamera.new()

	func _init() -> void:
		add_child(player)
		add_child(youn)
		add_child(camera_rig)

	func freeze_actors() -> void:
		player.set_physics_process(false)
		youn.set_physics_process(false)

	func freeze_camera() -> void:
		camera_rig.enabled = false


func test_async_flow_token_se_cancela_al_salir_su_owner() -> void:
	var owner := Node.new()
	add_child_autofree(owner)
	var token = AsyncFlowTokenScript.new(owner)

	owner.queue_free()
	await get_tree().process_frame

	assert_false(token.is_active())


func test_lease_restaura_el_estado_previo_e_idempotente() -> void:
	var tree_was_paused := get_tree().paused
	get_tree().paused = false
	var hud := FakeHud.new()
	hud.paused = true
	hud.clock_visible = false
	hud.status_visible = false
	var party := FakeParty.new()
	add_child_autofree(party)
	party.player.set_physics_process(true)
	party.youn.set_physics_process(true)
	var mouse_before := Input.mouse_mode

	var lease = WorldTransitionLeaseScript.new(hud, party, {"pause_tree": true})
	assert_true(hud.paused)
	assert_false(party.player.is_physics_processing())
	assert_false(party.camera_rig.enabled)
	assert_true(get_tree().paused)

	lease.release()
	lease.release()

	assert_true(hud.paused)
	assert_false(hud.clock_visible)
	assert_false(hud.status_visible)
	assert_true(party.player.is_physics_processing())
	assert_true(party.youn.is_physics_processing())
	assert_true(party.camera_rig.enabled)
	assert_false(get_tree().paused)
	assert_eq(Input.mouse_mode, mouse_before)
	get_tree().paused = tree_was_paused
