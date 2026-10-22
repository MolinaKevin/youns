class_name WorldYounCombatHandoff
extends RefCounted

## El handoff real a la escena de combate: el popup "Enter para pelear" y el
## cambio de escena. No sabe nada de diálogo — host._begin_encounter() o
## WorldYounConversation llaman a engage() cuando corresponde pelear.
## `host` es el WorldYoun dueño exclusivo de esta instancia.

var host: WorldYoun
var waiting := false

func _init(p_host: WorldYoun) -> void:
	host = p_host

func engage() -> void:
	host._engaging_combat = true
	host._interaction.update_prompt_visibility()
	host._ai.start_idle()
	host.velocity = Vector3.ZERO
	if host._player:
		host._player.velocity = Vector3.ZERO
		host._player.set_physics_process(false)
		var to_enemy := (host.global_position - host._player.global_position) * Vector3(1, 0, 1)
		if to_enemy.length() > 0.01:
			host._player.rotation.y = atan2(to_enemy.x, to_enemy.z)
		var to_player := ((host._player.global_position - host.global_position) * Vector3(1, 0, 1))
		if to_player.length() > 0.01:
			host.rotation.y = atan2(to_player.x, to_player.z)
	host.set_physics_process(false)
	var popup_text := host.youn_data.youn_name
	var biome := ZoneManager.get_current_biome()
	if biome != null:
		popup_text += "\n" + LocalizationState.biome_name(biome.id, biome.id)
	popup_text += "\n" + LocalizationState.t("world.enemy.press_enter")
	host.popup_label.text = popup_text
	host.popup_panel.visible = true
	waiting = true
	host.process_mode = Node.PROCESS_MODE_ALWAYS
	PauseMenu.enabled = false
	host.get_tree().paused = true

## true si el evento se consumió (estaba esperando confirmación), haya sido
## o no la tecla correcta.
func handle_input(event: InputEvent) -> bool:
	if not waiting:
		return false
	if event.is_action_pressed("ui_accept"):
		waiting = false
		host.popup_panel.visible = false
		host.get_tree().paused = false
		host.process_mode = Node.PROCESS_MODE_PAUSABLE
		host.get_viewport().set_input_as_handled()
		_start_transition()
	return true

func _start_transition() -> void:
	GameState.combat_return_pending = true
	GameState.combat_return_position = host._player.global_position if host._player else host.global_position
	GameState.combat_world_enemy_id = host.world_enemy_id
	GameState.pending_wild_youn_data = host.youn_data
	GameState.combat_biome = ZoneManager.get_current_biome()
	if GameState.player_save != null and "bathroom" in StatsManager.active_states:
		GameState.player_save.bathroom_pending_after_combat = true
	host.get_tree().change_scene_to_file("res://features/combat/scene/combat.tscn")
