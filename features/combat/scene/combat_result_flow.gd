class_name CombatResultFlow
extends RefCounted

## Qué pasa cuando el combate termina: detecta el HP en 0, dispara la
## pantalla de fin de lucha (ganaste/perdiste) y, al continuar, vuelve al
## mundo con la recompensa si corresponde. `host` es el Combat dueño
## exclusivo de esta instancia.

var host: Combat

func _init(p_host: Combat) -> void:
	host = p_host

func check_combat_end() -> bool:
	if host.state.enemy_hp <= 0:
		host.hand_section.disable_cards()
		host.end_turn_button.disabled = true
		if not host._combat_finished:
			host._combat_finished = true
			host.log_message(LocalizationState.t("combat.win"))
			_show_victory.call_deferred()
		return true
	if host.state.player_hp <= 0:
		host.hand_section.disable_cards()
		host.end_turn_button.disabled = true
		if not host._combat_finished:
			host._combat_finished = true
			host.log_message(LocalizationState.t("combat.lose"))
			host.map_area.play_player_anim("die")
			_show_defeat.call_deferred()
		return true
	return false

## Muestra la pantalla de fin de lucha y, al continuar, vuelve al mundo.
func _show_victory() -> void:
	await _prepare_result_screen()
	# Solo los combates del mundo dan recompensa (no el combate rápido del título).
	var rewarded := GameState.world_combat.active
	var gold := Combat.VICTORY_GOLD if rewarded else 0
	host.result_screen.show_victory(_victory_stat_lines() + _echo_reward_lines() if rewarded else [], gold)
	await host.result_screen.continue_pressed
	if rewarded:
		GameState.player_save.gold += gold
		var youn = PartyManager.youn
		YounStatRules.reward(GameState.player_save, Combat.VICTORY_STAT_GAINS,
			youn.youn_data if is_instance_valid(youn) else null)
		LaboratoryState.deposit_echoes(host.state.echoes_earned)
	_leave_combat()

## [[nombre, cantidad], ...] de VICTORY_STAT_GAINS para la pantalla de victoria.
func _victory_stat_lines() -> Array:
	var lines := []
	for key in Combat.VICTORY_STAT_GAINS:
		lines.append([LocalizationState.t("youn_stat." + key), Combat.VICTORY_STAT_GAINS[key]])
	return lines

## [[nombre del Eco, cantidad], ...] de lo juntado en el combate.
func _echo_reward_lines() -> Array:
	var lines := []
	for echo_id in host.state.echoes_earned:
		lines.append([LocalizationState.item_name(echo_id, echo_id), host.state.echoes_earned[echo_id]])
	return lines

## Provisorio: derrota sin penalidad todavía. Se vuelve al mundo igual que
## al ganar (el enemigo del mundo huye, así no te vuelve a atrapar al aparecer).
func _show_defeat() -> void:
	await _prepare_result_screen()
	host.result_screen.show_defeat()
	await host.result_screen.continue_pressed
	_leave_combat()

func _prepare_result_screen() -> void:
	host.enemy_reveal.hide()
	host.wildcards_ui.hide()
	await host.get_tree().create_timer(Combat.VICTORY_SCREEN_DELAY).timeout

func _leave_combat() -> void:
	if not GameState.world_combat.active:
		# Combate abierto directo desde el editor: no hay mundo al que volver.
		host.get_tree().reload_current_scene()
		return
	host.get_tree().change_scene_to_file("res://features/world/game_world/game_world.tscn")
