class_name WorldYounCombatHandoff
extends RefCounted

## El handoff real a la escena de combate: el popup "Enter para pelear" y el
## cambio de escena. No sabe nada de diálogo — host.begin_encounter() o
## WorldYounConversation llaman a engage() cuando corresponde pelear.
## `host` es el WorldYoun dueño exclusivo de esta instancia.

var host: WorldYoun
var waiting := false
var _modal: ModalScreenContext
var _combat_runtime: WorldCombatRuntime

func _init(p_host: WorldYoun) -> void:
	host = p_host
	_modal = ModalScreenContext.new(ModalScreenHost.from_runtime())
	_combat_runtime = WorldCombatRuntime.from_runtime()

func engage() -> void:
	# Puede llegar desde una señal de diálogo que se resolvió tarde. Si ya hay
	# un combate del mundo en curso, este Youn no puede secuestrar el input.
	if waiting or _combat_runtime.is_active():
		return
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
	_modal.enter_overlay()

## true si el evento se consumió (estaba esperando confirmación), haya sido
## o no la tecla correcta.
func handle_input(event: InputEvent) -> bool:
	if not waiting:
		return false
	if event.is_action_pressed("ui_accept"):
		waiting = false
		host.popup_panel.visible = false
		_modal.exit_overlay()
		host.process_mode = Node.PROCESS_MODE_PAUSABLE
		host.get_viewport().set_input_as_handled()
		_start_transition()
	return true

func _start_transition() -> void:
	_combat_runtime.begin(
		host.combat_start_position(),
		host.world_enemy_id,
		host.youn_data,
	)
	SceneNavigator.change_scene_resumed(host.get_tree(), ScenePaths.COMBAT)
