class_name WorldYounCombatHandoff
extends RefCounted

## El handoff real a la escena de combate: el popup "Enter para pelear" y el
## cambio de escena. No sabe nada de diálogo — host.begin_encounter() o
## WorldYounConversation llaman a engage() cuando corresponde pelear.
## `host` es el WorldYoun dueño exclusivo de esta instancia.

var host: WorldYoun
var waiting := false

func _init(p_host: WorldYoun) -> void:
	host = p_host

func engage() -> void:
	host.prepare_encounter()
	host.set_player_combat_locked(true)
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
	GameState.world_combat.begin(
		host.combat_start_position(),
		host.world_enemy_id,
		host.youn_data,
		ZoneManager.get_current_biome(),
	)
	if GameState.player_save != null and "bathroom" in StatsManager.active_states:
		GameState.player_save.bathroom_pending_after_combat = true
	host.get_tree().change_scene_to_file("res://features/combat/scene/combat.tscn")
