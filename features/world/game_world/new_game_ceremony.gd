class_name NewGameCeremony
extends Node3D

## Escena autónoma que antecede al mundo: sólo Pachamama, iluminación tenue y
## fondo negro. No instancia zonas ni el tutorial para que la apertura no deje
## el mapa visible detrás del diálogo.

const NarrativeYouns := preload("res://data/youns/narrative_youn_catalog.gd")
const PACHAMAMA_PATH := NarrativeYouns.PACHAMAMA
const WORLD_LOADING := "res://features/world/game_world/world_loading.tscn"
const GAME_WORLD := "res://features/world/game_world/game_world.tscn"
const HUB_SCENE := "res://features/world/zones/zone_hub.tscn"
const NEWEN_PATH := NarrativeYouns.NEWEN
const NGURUVILU_PATH := NarrativeYouns.NGURUVILU
const Preloader := preload("res://features/world/game_world/new_game_ceremony_preloader.gd")
const CeremonyNameInput := preload("res://features/world/game_world/ceremony_name_input.gd")
const DebugLog := preload("res://shared/debug_logging.gd")
const ENTRANCE_SECONDS := 6.5
## Mantiene el ciclo de caminata sincronizado con el mismo modelo en el mundo.
const WALK_ANIMATION_SPEED := 1.0
const MODEL_SCALE_MULTIPLIER := 1.45
const MODEL_HEIGHT_OFFSET := 0.8

var _data: YounData
var _model: Node3D
var _sequence_completed := false
var _entering_world := false
var _player_name := ""
var _companion_name := ""
var _preloader := Preloader.new()
var _flow: AsyncFlowToken


func _ready() -> void:
	_flow = AsyncFlowToken.new(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_log("_ready: aislando la escena.")
	# ZoneManager y PartyManager son autoloads: pueden conservar nodos y una
	# cámara de una sesión anterior. La ceremonia debe aislarse por completo.
	ModalScreenContext.enter_fullscreen(ModalScreenHost.from_runtime())
	_data = NarrativeYouns.pachamama()
	if _data == null:
		push_error("[NewGameCeremony:%s] No se pudo cargar Pachamama." % get_instance_id())
		return
	_log("Pachamama cargada: id=%s." % _data.id)
	_build_black_stage()
	_request_world_preload()
	_log("Escenario negro, cámara y modelo construidos; difiriendo secuencia.")
	_run.call_deferred()


func _request_world_preload() -> void:
	_preloader.request(GAME_WORLD, HUB_SCENE)


func _collect_preloaded_world() -> void:
	_preloader.collect(GAME_WORLD, HUB_SCENE)


func _build_black_stage() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.16, 0.16, 0.2, 1.0)
	environment.ambient_light_energy = 0.35
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.45, 6.4)
	camera.fov = 31.0
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.5, 0.0), Vector3.UP)
	camera.make_current()

	var light := OmniLight3D.new()
	light.position = Vector3(-1.8, 3.8, 3.0)
	light.light_color = Color(0.84, 0.75, 1.0, 1.0)
	light.light_energy = 4.5
	light.omni_range = 12.0
	add_child(light)

	_model = _instantiate_model(
		_data.scene_walk if _data.scene_walk != null else _data.scene_idle,
		WALK_ANIMATION_SPEED
	)
	if _model == null:
		return
	_model.position = Vector3(4.0, _data.mesh_y_offset + MODEL_HEIGHT_OFFSET, 0.0)
	# El FBX tiene su frente invertido respecto del eje visual: -π/2 lo hace
	# entrar mirando hacia la izquierda de la pantalla.
	_model.rotation.y = -PI * 0.5
	add_child(_model)


func _instantiate_model(scene: PackedScene, animation_speed := 1.0) -> Node3D:
	if scene == null:
		return null
	var model := scene.instantiate() as Node3D
	if model == null:
		return null
	model.scale = Vector3.ONE * _data.mesh_scale * MODEL_SCALE_MULTIPLIER
	if _data.texture != null:
		var material := StandardMaterial3D.new()
		material.albedo_texture = _data.texture
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		for mesh in Node3DSearch.find_meshes(model):
			mesh.material_override = material
	var animation_player := Node3DSearch.find_anim_player(model)
	if animation_player != null:
		animation_player.speed_scale = animation_speed
		var animations := animation_player.get_animation_list()
		if not animations.is_empty():
			var animation := animation_player.get_animation(animations[0])
			if animation != null:
				animation.loop_mode = Animation.LOOP_LINEAR
			animation_player.play(animations[0])
	return model


func _run() -> void:
	_log("Inicio de secuencia; Pachamama entra en escena.")
	if _model != null:
		var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(_model, "position:x", 0.0, ENTRANCE_SECONDS)
		await tween.finished
		if not _flow.is_active(): return
		_settle_facing_camera()
	_log("Entrada terminada; primer diálogo.")
	await _say([LocalizationState.t("ceremony.greeting"), LocalizationState.t("ceremony.player_question")])
	if not _flow.is_active(): return
	_player_name = await _ask_name(LocalizationState.t("ceremony.player_question"), LocalizationState.t("ceremony.player_placeholder"), false)
	if not _flow.is_active(): return
	_log("Saludo terminado; afinidad del compañero.")
	var partner_choice := await _ask(LocalizationState.t("ceremony.path_question"), [LocalizationState.t("ceremony.path_forest"), LocalizationState.t("ceremony.path_lake")], false)
	if not _flow.is_active(): return
	_apply_starting_youn(NEWEN_PATH if partner_choice == 0 else NGURUVILU_PATH)
	await _ask(LocalizationState.t("ceremony.social_question"), [LocalizationState.t("ceremony.social_people"), LocalizationState.t("ceremony.social_solitude")], false)
	if not _flow.is_active(): return
	_companion_name = await _ask_name(LocalizationState.t("ceremony.companion_question"), _starting_youn_name())
	if not _flow.is_active(): return
	_save_ceremony_names()
	_log("Preguntas y nombres terminados; pasando a la ciudad.")
	_sequence_completed = true
	_enter_world()


func _settle_facing_camera() -> void:
	if _model == null:
		return
	var final_position := _model.position
	_model.queue_free()
	_model = _instantiate_model(_data.scene_idle if _data.scene_idle != null else _data.scene_walk)
	if _model == null:
		return
	_model.position = final_position
	_model.rotation.y = -PI * 0.5
	add_child(_model)
	var turn := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Con la orientación propia de este modelo, 0 es mirar a la cámara.
	turn.tween_property(_model, "rotation:y", 0.0, 0.55)
	await turn.finished
	if not _flow.is_active(): return


func _say(lines: Array[String]) -> void:
	_log("Dialogue.start: %s" % " | ".join(lines))
	DialogueLines.say_many(_data, lines)
	await Dialogue.dialogue_finished
	if not _flow.is_active(): return
	_log("Dialogue.finished.")


func _ask(question: String, options: Array[String], confirm_choice := true) -> int:
	_log("Pregunta: %s" % question)
	await _say([question])
	_log("Abriendo opciones: %s" % " | ".join(options))
	var choice: int = await Dialogue.ask(options)
	if not _flow.is_active(): return -1
	_log("Opción recibida: %s" % choice)
	if confirm_choice and choice >= 0 and choice < options.size():
		await _say([LocalizationState.t("ceremony.choice_confirmed", [options[choice]])])
	return choice


func _apply_starting_youn(path: String) -> void:
	var save := PlayerSessionAccess.save()
	if save == null:
		return
	GameState.save_service.setup_starting_youn(save, GameState.get_total_hours(), path)
	_log("Youn inicial elegido: %s." % path)


func _starting_youn_name() -> String:
	var save := PlayerSessionAccess.save()
	if save == null:
		return LocalizationState.t("ceremony.companion_placeholder")
	var data := NarrativeYouns.youn(save.current_youn_path)
	return data.youn_name if data != null else LocalizationState.t("ceremony.companion_placeholder")


func _save_ceremony_names() -> void:
	var save := PlayerSessionAccess.save()
	if save == null:
		return
	save.player_name = _player_name
	save.companion_name = _companion_name


func _ask_name(prompt: String, placeholder: String, announce_prompt := true) -> String:
	if announce_prompt:
		await _say([prompt])
	_log("Abriendo teclado virtual.")
	return await CeremonyNameInput.new(self, _flow).ask(prompt, placeholder)


func _enter_world() -> void:
	if not _sequence_completed:
		return
	if _entering_world:
		return
	_entering_world = true
	_log("_enter_world: preparando entrada al mundo.")
	GameState.set_new_game_ceremony_completed(true)
	call_deferred("_change_to_world")


func _change_to_world() -> void:
	if _flow == null or not _flow.is_active():
		return
	_log("change_scene_to_file(WorldLoading).")
	_collect_preloaded_world()
	var result := SceneNavigator.change_scene_resumed(get_tree(), WORLD_LOADING)
	if result != OK:
		push_error("NewGameCeremony: no se pudo cargar WorldLoading (%s)." % result)


func _exit_tree() -> void:
	if _flow != null:
		_flow.cancel()


func _log(message: String) -> void:
	if DebugLog.verbose_enabled():
		print("[NewGameCeremony:%s] %s" % [get_instance_id(), message])
