extends GutTest

const AsyncFlowTokenScript := preload("res://shared/async_flow_token.gd")
const WorldTransitionLeaseScript := preload("res://shared/world_transition_lease.gd")
const ModalScreenHostScript := preload("res://shared/modal_screen_host.gd")
const ModalScreenHudPortScript := preload("res://shared/modal_screen_hud_port.gd")
const ModalScreenWorldPortScript := preload("res://shared/modal_screen_world_port.gd")
const ModalScreenPartyPortScript := preload("res://shared/modal_screen_party_port.gd")


class FakeHud extends ModalScreenHostPort:
	var paused := false
	var _clock_visible := true
	var status_visible := true

	func clock_paused() -> bool: return paused
	func clock_visible() -> bool: return _clock_visible
	func set_clock_paused(value: bool) -> void: paused = value
	func set_clock_visible(value: bool) -> void: _clock_visible = value
	func set_youns_status_visible(value: bool) -> void: status_visible = value
	func youns_status_visible() -> bool: return status_visible


class FakeCamera extends Node:
	var enabled := true


class FakeModalHud extends ModalScreenHudPortScript:
	var clock_is_visible := true
	var clock_is_paused := false
	var status_is_visible := true

	func set_clock_visible(value: bool) -> void: clock_is_visible = value
	func clock_visible() -> bool: return clock_is_visible
	func set_clock_paused(value: bool) -> void: clock_is_paused = value
	func clock_paused() -> bool: return clock_is_paused
	func set_youns_status_visible(value: bool) -> void: status_is_visible = value
	func youns_status_visible() -> bool: return status_is_visible


class FakeModalWorld extends ModalScreenWorldPortScript:
	var is_visible := true

	func set_world_visible(value: bool) -> void: is_visible = value


class FakeModalParty extends ModalScreenPartyPortScript:
	var is_visible := true

	func set_party_visible(value: bool) -> void: is_visible = value


class FakeParty extends WorldTransitionPartyPort:
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
	func snapshot_transition_state() -> Dictionary:
		return {
			"player_physics": player.is_physics_processing(),
			"youn_physics": youn.is_physics_processing(),
			"camera_enabled": camera_rig.enabled,
		}

	func restore_transition_state(snapshot: Dictionary, restore_actors: bool, restore_camera: bool) -> void:
		if restore_actors:
			player.set_physics_process(snapshot["player_physics"])
			youn.set_physics_process(snapshot["youn_physics"])
		if restore_camera:
			camera_rig.enabled = snapshot["camera_enabled"]


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
	hud._clock_visible = false
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
	assert_false(hud.clock_visible())
	assert_false(hud.status_visible)
	assert_true(party.player.is_physics_processing())
	assert_true(party.youn.is_physics_processing())
	assert_true(party.camera_rig.enabled)
	assert_false(get_tree().paused)
	assert_eq(Input.mouse_mode, mouse_before)
	get_tree().paused = tree_was_paused


func test_lease_restaura_el_grupo_sin_pausar_el_arbol() -> void:
	var party := FakeParty.new()
	add_child_autofree(party)
	party.player.set_physics_process(true)
	party.youn.set_physics_process(true)
	var lease = WorldTransitionLeaseScript.new(FakeHud.new(), party)

	assert_false(party.player.is_physics_processing())
	lease.release()
	assert_true(party.player.is_physics_processing())
	assert_true(party.youn.is_physics_processing())
	assert_true(party.camera_rig.enabled)


func test_modal_host_delega_a_puertos_tipados() -> void:
	var hud := FakeModalHud.new()
	var world := FakeModalWorld.new()
	var party := FakeModalParty.new()
	var host = ModalScreenHostScript.new(hud, world, party)

	host.set_clock_visible(false)
	host.set_clock_paused(true)
	host.set_youns_status_visible(false)
	host.set_world_visible(false)
	host.set_party_visible(false)

	assert_false(host.clock_visible())
	assert_true(host.clock_paused())
	assert_false(host.youns_status_visible())
	assert_false(world.is_visible)
	assert_false(party.is_visible)
