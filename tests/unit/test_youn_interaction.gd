extends GutTest

# Menú rápido: el jugador mira al Youn, el Youn se acerca, el jugador hace la
# animación y recién después se aplican los cambios.

const YounInteraction := preload("res://features/world/party/youn_interaction.gd")

var _pos := Vector3.ZERO
var _save_before: PlayerSaveData


func before_each() -> void:
	_save_before = GameState.player_save
	GameState.player_save = PlayerSaveData.new()
	_pos = PartyManager.player.global_position
	PartyManager.player.global_position = Vector3(0, 0.9, 0)
	PartyManager.player.rotation.y = 0.0
	PartyManager.youn.global_position = Vector3(3, 0.9, 0)


## Arranca la escena sin esperarla, para mirar qué pasa mientras corre.
func _start(anim: String) -> void:
	var interaction = YounInteraction
	interaction.run(anim)


func after_each() -> void:
	PartyManager.place_at(_pos)
	GameState.player_save = _save_before


func test_el_youn_se_acerca_y_el_jugador_lo_mira() -> void:
	var player := PartyManager.player
	var youn := PartyManager.youn
	_start("talk")
	assert_true(YounInteraction.running)
	assert_false(player.is_physics_processing(), "el jugador no se mueve durante la escena")
	await wait_until(func() -> bool: return not YounInteraction.running, 10.0)
	var flat := Vector2(youn.global_position.x - player.global_position.x,
		youn.global_position.z - player.global_position.z)
	assert_almost_eq(flat.length(), YounInteraction.MEET_DISTANCE, 0.05)
	assert_almost_eq(player.rotation.y, atan2(1.0, 0.0), 0.05, "mira hacia el Youn (+X)")
	assert_true(player.is_physics_processing())
	assert_true(youn.is_physics_processing())


func test_el_jugador_hace_la_animacion() -> void:
	_start("angry")
	await wait_until(func() -> bool:
		return PartyManager.player.get_node("Body").get_current_animation() == "angry", 3.0)
	assert_eq(PartyManager.player.get_node("Body").get_current_animation(), "angry")
	await wait_until(func() -> bool: return not YounInteraction.running, 10.0)
	assert_eq(PartyManager.player.get_node("Body").get_current_animation(), "idle")


func test_los_stats_cambian_al_terminar_la_escena() -> void:
	var save := GameState.player_save
	save.felicidad = 50
	QuickMenu._selected = "left"
	QuickMenu._activate()
	assert_eq(save.felicidad, 50, "todavía no")
	await wait_until(func() -> bool: return not YounInteraction.running, 10.0)
	await wait_frames(1)
	assert_eq(save.felicidad, 48)
