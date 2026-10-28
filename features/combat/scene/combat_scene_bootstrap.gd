class_name CombatSceneBootstrap
extends RefCounted

## Preparación de la escena de combate independiente del estado de la partida:
## biome, visibilidad global, cámara y entorno 3D.

var host

func _init(p_host) -> void:
	host = p_host

func enter_tree() -> void:
	var combat_map := host.get_node_or_null("CombatWorld/MapArea") as MapArea
	if combat_map != null:
		combat_map.setup_biome(GameState.world_combat.biome)

func ready_environment() -> void:
	GlobalHUD.set_clock_visible(false)
	GlobalHUD.set_clock_paused(true)
	GlobalHUD.set_youns_status_visible(false)
	GlobalHUD.set_debug_stats_visible(false)
	ZoneManager.set_world_visible(false)
	PartyManager.set_party_visible(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var cam: Camera3D = host.get_node("CombatWorld/Camera3D")
	cam.look_at_from_position(Vector3(-5.0, 18.0, 39.0), Vector3(15.0, 0.0, 15.0), Vector3.UP)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.08, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.4, 0.5)
	env.ambient_light_energy = 0.8
	var world_environment := WorldEnvironment.new()
	world_environment.environment = env
	host.get_node("CombatWorld").add_child(world_environment)
