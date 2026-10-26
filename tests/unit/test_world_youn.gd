extends GutTest

const WORLD_YOUN_SCENE := preload("res://features/world/npcs/world_youn.tscn")

var _youn: WorldYoun
var _player: CharacterBody3D
var _player_position := Vector3.ZERO
var _player_rotation := 0.0
var _player_velocity := Vector3.ZERO
var _player_physics_processing := true


func before_each() -> void:
	_player = PartyManager.player
	_player_position = _player.global_position
	_player_rotation = _player.rotation.y
	_player_velocity = _player.velocity
	_player_physics_processing = _player.is_physics_processing()
	_player.global_position = Vector3.ZERO
	_player.rotation.y = 0.0
	_player.velocity = Vector3(2, 0, 1)

	_youn = WORLD_YOUN_SCENE.instantiate()
	_youn.youn_data = YounData.new()
	_youn.position = Vector3(4, 0, 0)
	add_child_autofree(_youn)
	await get_tree().process_frame


func after_each() -> void:
	_player.global_position = _player_position
	_player.rotation.y = _player_rotation
	_player.velocity = _player_velocity
	_player.set_physics_process(_player_physics_processing)


func test_prepare_encounter_detiene_y_orienta_a_los_dos() -> void:
	_youn.velocity = Vector3(1, 0, 3)
	_youn.prepare_encounter()

	assert_true(_youn.is_engaging_combat())
	assert_eq(_youn.velocity, Vector3.ZERO)
	assert_eq(_player.velocity, Vector3.ZERO)
	assert_almost_eq(_player.rotation.y, PI * 0.5, 0.01)
	assert_almost_eq(_youn.rotation.y, -PI * 0.5, 0.01)


func test_finalizar_encuentro_sin_combate_vuelve_a_liberar_el_estado() -> void:
	_youn.prepare_encounter()
	_youn.finish_non_combat_encounter()

	assert_false(_youn.is_engaging_combat())


func test_bloqueo_de_combate_y_posicion_inicial_usan_al_jugador() -> void:
	assert_eq(_youn.combat_start_position(), _player.global_position)

	_youn.set_player_combat_locked(true)
	assert_false(_player.is_physics_processing())
	_youn.set_player_combat_locked(false)
	assert_true(_player.is_physics_processing())
