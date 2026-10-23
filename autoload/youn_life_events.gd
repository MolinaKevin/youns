extends Node

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

## Lo registra game_world.gd en su _ready() (cada vez que esa escena se crea,
## p. ej. al volver de un combate) — la cinemática de evolución la necesita
## para apagar el sol / poner fondo negro.
var world_lighting: WorldLighting

var _sleep_penalty_applied := false
var _was_in_sleep_range := false
var _slept_this_cycle := false
var _sleep_tracking_initialized := false
var _sick_sleep_count := 0

## Máximo de cacas en el suelo: al pasarlo se borra la más vieja.
const MAX_POOPS := 10
var _poops: Array[Node3D] = []


func _ready() -> void:
	GameState.clock_changed.connect(_check_sleep_penalty)
	GameState.clock_changed.connect(_check_end_of_night)
	StatsManager.bathroom_accident.connect(_on_bathroom_accident)
	StatsManager.evolution_triggered.connect(_on_evolution_triggered)
	StatsManager.reincarnation_triggered.connect(_on_reincarnation_triggered)


func _current_zone_node() -> Node:
	var zone: Node = ZoneManager.get_current_zone_node()
	return zone if zone else self


# ── Sueño ─────────────────────────────────────────────────────────────────────

## Lo llama game_world.gd cuando el jugador elige dormir desde el menú: marca
## que durmió esta noche y, si estaba enfermo, cuenta para la curación.
func mark_player_slept() -> void:
	_slept_this_cycle = true
	if GameState.player_save != null and GameState.player_save.enfermo:
		_sick_sleep_count += 1
		if _sick_sleep_count >= 2:
			_sick_sleep_count = 0
			StatsManager.set_enfermo(false)
			StatsManager.add_care_mistake(1)

func _check_sleep_penalty(hour: float, _day: int) -> void:
	var youn_node = PartyManager.youn if PartyManager else null
	if not is_instance_valid(youn_node) or youn_node.youn_data == null:
		return
	var data: YounData = youn_node.youn_data
	if not _hour_in_range(hour, data.sleep_hour, data.wake_hour):
		_sleep_penalty_applied = false
		return
	if _sleep_penalty_applied:
		return
	var penalty_h := (data.sleep_hour + 1) % 24
	if _hour_in_range(hour, penalty_h, data.wake_hour):
		_sleep_penalty_applied = true
		StatsManager.add_care_mistake(1)

func _check_end_of_night(hour: float, _day: int) -> void:
	var youn_node = PartyManager.youn if PartyManager else null
	if not is_instance_valid(youn_node) or youn_node.youn_data == null:
		return
	var data: YounData = youn_node.youn_data
	var in_sleep := _hour_in_range(hour, data.sleep_hour, data.wake_hour)
	if not _sleep_tracking_initialized:
		_was_in_sleep_range = in_sleep
		_sleep_tracking_initialized = true
		return
	if in_sleep and not _was_in_sleep_range:
		_slept_this_cycle = false
	if not in_sleep and _was_in_sleep_range:
		if not _slept_this_cycle:
			StatsManager.add_salud(-20)
			if GameState.player_save != null and GameState.player_save.energia < 20:
				StatsManager.set_enfermo(true)
	_was_in_sleep_range = in_sleep

func _hour_in_range(hour: float, from_h: int, to_h: int) -> bool:
	if from_h > to_h:
		return hour >= float(from_h) or hour < float(to_h)
	return hour >= float(from_h) and hour < float(to_h)


# ── Baño ──────────────────────────────────────────────────────────────────────

## Deja una caca en el suelo donde está el Youn. Va colgada de la zona actual,
## así se oculta en los interiores y se va si la zona se descarga.
## Al agregar una animación: StatsManager.block_emotions() al inicio,
## StatsManager.unblock_emotions() en el callback de fin de animación.
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
func _on_reincarnation_triggered(from_data: YounData, cause: String) -> void:
	var sequence := ReincarnationSequence.new()
	sequence.setup(from_data, cause)
	add_child(sequence)

## Partida cargada en medio de una muerte: se retoma desde el principio. Lo
## llama game_world.gd en su _ready() (partida nueva/cargada o vuelta de combate).
func restore_pending_reincarnation() -> void:
	if not "dying" in StatsManager.active_states:
		return
	var ps := GameState.player_save
	var from_data: YounData = null
	if ps and not ps.current_youn_path.is_empty() and ResourceLoader.exists(ps.current_youn_path):
		from_data = load(ps.current_youn_path) as YounData
	var cause: String = StatsManager.active_states["dying"].get("cause", ReincarnationRules.CAUSE_AGE)
	call_deferred("_on_reincarnation_triggered", from_data, cause)


# ── Evolución ─────────────────────────────────────────────────────────────────

## Partida cargada en medio de una evolución: se retoma desde el principio.
## Lo llama game_world.gd en su _ready() (partida nueva/cargada o vuelta de combate).
func restore_pending_evolution() -> void:
	if not "evolving" in StatsManager.active_states:
		return
	var target_path: String = StatsManager.active_states["evolving"].get("target_youn_path", "")
	if target_path.is_empty():
		return
	var ps := GameState.player_save
	var from_data: YounData = null
	if ps and not ps.current_youn_path.is_empty() and ResourceLoader.exists(ps.current_youn_path):
		from_data = load(ps.current_youn_path) as YounData
	var to_data: YounData = null
	if ResourceLoader.exists(target_path):
		to_data = load(target_path) as YounData
	call_deferred("_on_evolution_triggered", from_data, to_data)

func _on_evolution_triggered(from_data: YounData, to_data: YounData) -> void:
	await get_tree().create_timer(4.0).timeout
	var cam_transform := get_viewport().get_camera_3d().global_transform
	PartyManager.camera_rig.enabled = false
	PartyManager.player.set_physics_process(false)
	PartyManager.youn.set_physics_process(false)
	GlobalHUD.set_clock_paused(true)

	var evo := EVOLUTION_SCENE.instantiate()
	_current_zone_node().add_child(evo)
	evo.global_position = PartyManager.youn.global_position

	var saved_env := world_lighting.world_env.environment
	evo.approach_finished.connect(func():
		world_lighting.freeze_transition()
		ZoneManager.set_world_visible(false)
		PartyManager.player.visible = false
		var bubble = PartyManager.youn.get_node_or_null("EmotionBubble")
		if bubble:
			bubble.freeze()
		GlobalHUD.set_clock_visible(false)
		GlobalHUD.set_youns_status_visible(false)
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
		world_lighting.world_env.environment = saved_env
		world_lighting.reapply_current_period()
		var result := StatsManager.complete_evolution()
		if to_data and PartyManager.youn.has_method("load_youn"):
			PartyManager.youn.load_youn(to_data)
		evo.queue_free()
		ZoneManager.set_world_visible(true)
		PartyManager.player.visible = true
		PartyManager.set_party_visible(true)
		# Pantalla de evolución: el jugador sigue quieto y el reloj parado hasta
		# que toca "Terminar".
		var screen := EvolutionScreen.new()
		screen.setup(result)
		screen.finished.connect(_show_evolution_discovery.bind(result))
		add_child(screen)
	)
	evo.start(from_data, to_data, cam_transform)

## "¡Evolución desbloqueada!" y la condición descubierta, después de la
## pantalla de evolución.
func _show_evolution_discovery(result: Dictionary) -> void:
	var screen := EvolutionDiscoveryScreen.new()
	screen.setup(result)
	screen.finished.connect(_end_evolution)
	add_child(screen)

## Devuelve el control al jugador después de las pantallas de evolución.
func _end_evolution() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	PartyManager.camera_rig.enabled = true
	PartyManager.player.set_physics_process(true)
	PartyManager.youn.set_physics_process(true)
	GlobalHUD.set_clock_paused(false)
	GlobalHUD.set_clock_visible(GlobalHUD.has_persistent_clock_ui())
	GlobalHUD.set_youns_status_visible(GlobalHUD.has_persistent_care_ui())
	var bubble = PartyManager.youn.get_node_or_null("EmotionBubble")
	if bubble:
		bubble.unfreeze()
