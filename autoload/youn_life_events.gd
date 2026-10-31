extends Node

const PlayerSessionAccessScript: GDScript = preload("res://shared/player_session_access.gd")

## Reacciones a los eventos de vida del Youn (sueño, baño, evolución,
## reencarnación). A diferencia de game_world.gd (que se destruye y recrea en
## cada combate), esto es un autoload: se conecta una sola vez a
## GameState.clock_changed / StatsManager y queda escuchando para siempre, sin
## importar en qué escena esté el jugador (hub, zona, interior). El chequeo en
## sí (si corresponde penalizar, evolucionar, etc.) ya se pausa solo en
## combate/diálogo porque depende de GameState.clock_changed, que no avanza
## mientras GameState.clock_paused es true (lo ponen Dialogue y combat.gd).
##
## Las cutscenes/pantallas se cuelgan de acá (autoload) o, si necesitan vivir
## en el mundo 3D (la caca, la cinemática de evolución), de
## ZoneManager.get_current_zone_node() — así se ocultan solas en los
## interiores y se liberan si la zona se descarga, igual que el resto de la
## geografía del mundo.

const Poop            := preload("res://features/world/items/poop.gd")
const EVOLUTION_SCENE  := preload("res://features/world/evolution/evolution_scene.tscn")
const EvolutionScreen  := preload("res://features/world/evolution/evolution_screen.gd")
const EvolutionDiscoveryScreen := preload("res://features/world/evolution/evolution_discovery_screen.gd")
const ReincarnationSequence := preload("res://features/world/reincarnation/reincarnation_sequence.gd")
const TypedResourceLoaderScript := preload("res://shared/typed_resource_loader.gd")
const YounSleepEventsScript := preload("res://shared/youn_sleep_events.gd")

## Lo registra game_world.gd en su _ready() (cada vez que esa escena se crea,
## p. ej. al volver de un combate) — la cinemática de evolución la necesita
## para apagar el sol / poner fondo negro.
var world_lighting: WorldLighting

var _sleep_events = YounSleepEventsScript.new()
## Solo una espera de evolución puede llegar a iniciar una cinemática. El token
## evita que una espera vieja continúe después de restaurar/cambiar de mundo.
var _evolution_delay: AsyncFlowToken
var _presentation := LifeEventPresentationHost.from_runtime()
var _active_evolution: EvolutionScene
var _active_reincarnation: Node
var _evolution_saved_environment: Environment
var _evolution_presentation_active := false

## Máximo de cacas en el suelo: al pasarlo se borra la más vieja.
const MAX_POOPS := 10
var _poops: Array[Node3D] = []


func _ready() -> void:
	GameState.clock_changed.connect(_on_clock_changed)
	StatsManager.bathroom_accident.connect(_on_bathroom_accident)

## Permite usar un host falso en pruebas o un host alternativo en otra escena.
func set_presentation_host(host: LifeEventPresentationHost) -> void:
	_presentation = host if host != null else LifeEventPresentationHost.from_runtime()


func _current_zone_node() -> Node:
	return _presentation.zone_or(self)


# ── Sueño ─────────────────────────────────────────────────────────────────────

## Lo llama game_world.gd cuando el jugador elige dormir desde el menú: marca
## que durmió esta noche y, si estaba enfermo, cuenta para la curación.
func mark_player_slept() -> void:
	_sleep_events.mark_player_slept()


func _on_clock_changed(hour: float, _day: int) -> void:
	_sleep_events.on_clock_changed(hour, PartyManager.youn if PartyManager else null)


# ── Baño ──────────────────────────────────────────────────────────────────────

## Deja una caca en el suelo donde está el Youn. Va colgada de la zona actual,
## así se oculta en los interiores y se va si la zona se descarga.
## Al agregar una animación: EmotionService.block() al inicio,
## EmotionService.unblock() en el callback de fin de animación.
func _on_bathroom_accident() -> void:
	var youn := PartyManager.youn
	if not is_instance_valid(youn):
		return
	var poop: Node3D = Poop.new()
	_current_zone_node().add_child(poop)
	poop.global_position = _ground_below(youn.global_position)
	poop.rotation.y = randf() * TAU
	# Array.filter() devuelve un Array sin tipo y su lambda recibe Variant; al
	# asignarlo a Array[Node3D] falla en tiempo de ejecución. Compactar a mano
	# conserva el tipo y descarta las cacas de zonas que ya se descargaron.
	var live_poops: Array[Node3D] = []
	for old_poop in _poops:
		if is_instance_valid(old_poop):
			live_poops.append(old_poop)
	_poops = live_poops
	_poops.append(poop)
	while _poops.size() > MAX_POOPS:
		_poops.pop_front().queue_free()

func _ground_below(pos: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(pos + Vector3.UP, pos + Vector3.DOWN * 5.0)
	query.exclude = [PartyManager.youn.get_rid(), PartyManager.player.get_rid()]
	var hit := PartyManager.youn.get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else pos


# ── Reencarnación ─────────────────────────────────────────────────────────────

## Fin de la vida del Youn: muerte, carta heredada, huevo y bebé.
## La capa de mundo llama esto al recibir la señal. Mantener las reglas de
## StatsManager libres de escenas 3D permite probarlas sin renderer.
func present_reincarnation(from_data: YounData, cause: String) -> void:
	if is_instance_valid(_active_reincarnation):
		return
	var sequence := ReincarnationSequence.new()
	_active_reincarnation = sequence
	sequence.setup(from_data, cause)
	sequence.tree_exiting.connect(func() -> void:
		if _active_reincarnation == sequence:
			_active_reincarnation = null
	, CONNECT_ONE_SHOT)
	add_child(sequence)

## Partida cargada en medio de una muerte: se retoma desde el principio. Lo
## llama game_world.gd en su _ready() (partida nueva/cargada o vuelta de combate).
func restore_pending_reincarnation() -> void:
	var emotions := StatsManager.services.emotions()
	if not emotions.has_state("dying"):
		return
	var ps: PlayerSaveData = PlayerSessionAccessScript.save() as PlayerSaveData
	var from_data: YounData = null
	if ps and not ps.current_youn_path.is_empty():
		from_data = TypedResourceLoaderScript.youn(ps.current_youn_path)
	var cause := EmotionStateEntry.cause_of(emotions.state_entry("dying"), ReincarnationRules.CAUSE_AGE)
	present_reincarnation(from_data, cause)


# ── Evolución ─────────────────────────────────────────────────────────────────

## Partida cargada en medio de una evolución: se retoma desde el principio.
## Lo llama game_world.gd en su _ready() (partida nueva/cargada o vuelta de combate).
func restore_pending_evolution() -> void:
	var emotions := StatsManager.services.emotions()
	if not emotions.has_state("evolving"):
		return
	var target_path := EmotionStateEntry.target_path_of(emotions.state_entry("evolving"))
	if target_path.is_empty():
		return
	var ps: PlayerSaveData = PlayerSessionAccessScript.save() as PlayerSaveData
	var from_data: YounData = null
	if ps and not ps.current_youn_path.is_empty():
		from_data = TypedResourceLoaderScript.youn(ps.current_youn_path)
	var to_data := TypedResourceLoaderScript.youn(target_path)
	present_evolution(from_data, to_data)

func present_evolution(from_data: YounData, to_data: YounData) -> void:
	# StatsManager también emite esta señal durante tests y fuera del mundo 3D.
	# En ese caso la evolución queda pendiente en el save y game_world la retoma
	# con restore_pending_evolution() cuando ya existen cámara, party e iluminación.
	if not _presentation.world_ready(world_lighting):
		return
	if is_instance_valid(_active_evolution) or _evolution_delay != null:
		return
	# world_lighting pertenece a game_world: si esa escena se descarga durante
	# la espera, el token se invalida antes de que la continuación toque nodos
	# viejos.
	var flow := AsyncFlowToken.new(world_lighting)
	_evolution_delay = flow
	await get_tree().create_timer(4.0).timeout
	if not flow.is_active() or _evolution_delay != flow:
		if _evolution_delay == flow:
			_evolution_delay = null
		return
	_evolution_delay = null
	if not _presentation.world_ready(world_lighting):
		return
	if not is_instance_valid(_presentation.youn()) or not _presentation.has_camera(get_viewport()):
		return
	var cam_transform := get_viewport().get_camera_3d().global_transform
	_presentation.freeze_party()
	_presentation.set_clock_paused(true)
	_evolution_presentation_active = true
	_evolution_saved_environment = world_lighting.world_env.environment

	var evo := EVOLUTION_SCENE.instantiate()
	_active_evolution = evo
	evo.tree_exiting.connect(_on_evolution_scene_exiting.bind(evo), CONNECT_ONE_SHOT)
	_current_zone_node().add_child(evo)
	evo.global_position = _presentation.youn().global_position

	evo.approach_finished.connect(func():
		if not flow.is_active() or not is_instance_valid(world_lighting):
			return
		world_lighting.freeze_transition()
		_presentation.set_world_visible(false)
		_presentation.player().visible = false
		var bubble = _presentation.youn().get_node_or_null("EmotionBubble")
		if bubble:
			bubble.freeze()
		_presentation.hide_hud()
		world_lighting.sun.light_energy = 4.0
		world_lighting.sun.light_color = Color(1.0, 0.95, 0.9)
		world_lighting.sun.shadow_enabled = false
		world_lighting.fill.light_energy = 2.5
		world_lighting.fill.light_color = Color(0.85, 0.9, 1.0)
		var black_env := Environment.new()
		black_env.background_mode = Environment.BG_COLOR
		black_env.background_color = world_lighting.world_env.environment.background_color
		black_env.fog_enabled = false
		black_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		black_env.ambient_light_color = Color(1.0, 1.0, 1.0)
		black_env.ambient_light_energy = 1.0
		world_lighting.world_env.environment = black_env
		var bg_tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		bg_tw.tween_property(black_env, "background_color", Color.BLACK, 0.5)
	)
	evo.finished.connect(func() -> void:
		if not flow.is_active() or not is_instance_valid(world_lighting):
			return
		world_lighting.world_env.environment = _evolution_saved_environment
		world_lighting.reapply_current_period()
		_evolution_presentation_active = false
		_active_evolution = null
		var result := StatsManager.services.life().complete_evolution()
		if to_data and _presentation.youn().has_method("load_youn"):
			_presentation.youn().load_youn(to_data)
		evo.queue_free()
		_presentation.set_world_visible(true)
		_presentation.player().visible = true
		_presentation.set_party_visible(true)
		# Pantalla de evolución: el jugador sigue quieto y el reloj parado hasta
		# que toca "Terminar".
		var screen := EvolutionScreen.new()
		screen.setup(result)
		screen.finished.connect(_show_evolution_discovery.bind(result, flow))
		add_child(screen)
	)
	evo.start(from_data, to_data, cam_transform)


func _on_evolution_scene_exiting(evo: EvolutionScene) -> void:
	if _active_evolution != evo:
		return
	_active_evolution = null
	_restore_interrupted_evolution()


## No existe cancelación por parte del jugador. Esta ruta sólo cubre que la
## escena se destruya por una transición técnica mientras ya congelamos mundo,
## cámara y HUD.
func _restore_interrupted_evolution() -> void:
	if not _evolution_presentation_active:
		return
	_evolution_presentation_active = false
	if is_instance_valid(world_lighting):
		world_lighting.world_env.environment = _evolution_saved_environment
		world_lighting.reapply_current_period()
	_presentation.set_world_visible(true)
	if is_instance_valid(_presentation.player()):
		_presentation.player().visible = true
	_presentation.set_party_visible(true)
	_presentation.restore_party()
	_presentation.set_clock_paused(false)
	_presentation.restore_hud()
	var youn := _presentation.youn()
	if is_instance_valid(youn):
		var bubble = youn.get_node_or_null("EmotionBubble")
		if bubble:
			bubble.unfreeze()

## "¡Evolución desbloqueada!" y la condición descubierta, después de la
## pantalla de evolución.
func _show_evolution_discovery(result: Dictionary, flow: AsyncFlowToken) -> void:
	if not flow.is_active():
		return
	var screen := EvolutionDiscoveryScreen.new()
	screen.setup(result)
	screen.finished.connect(_end_evolution.bind(flow))
	add_child(screen)

## Devuelve el control al jugador después de las pantallas de evolución.
func _end_evolution(flow: AsyncFlowToken) -> void:
	if not flow.is_active():
		return
	flow.cancel()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_presentation.restore_party()
	_presentation.set_clock_paused(false)
	_presentation.restore_hud()
	var bubble = _presentation.youn().get_node_or_null("EmotionBubble")
	if bubble:
		bubble.unfreeze()
