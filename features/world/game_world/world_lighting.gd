class_name WorldLighting
extends Node3D

## Transición de luz ambiente según la hora del día. Reacciona sola a
## GameState.clock_changed — alcanza con instanciar esta escena como hija del
## mundo, no hace falta llamar nada desde afuera.
##
## El WorldEnvironment/las luces se arman por código (no como nodos de
## escena): se probó declararlos en el .tscn y, con los mismos valores
## exactos, se veía distinto en el editor — un comportamiento de Godot que no
## se pudo diagnosticar más a fondo sin GPU real. Por eso esta clase replica
## tal cual la función `_setup_environment()` que ya se sabía que andaba bien.
##
## La cinemática de evolución necesita tomar control manual de la luz durante
## un rato (apagar el sol, fondo negro, etc.) — para eso expone `world_env`/
## `sun`/`fill` públicos y `freeze_transition()`/`reapply_current_period()`.

# Un keyframe por sector. Noche usa hora 20→28 (28 = 4h del día siguiente) para manejar el wrap.
# [hora, sky, fog_color, fog_density, fog_energy, ambient_color, ambient_energy, sun_color, sun_energy, fill_energy]
const LIGHTING_KF := [
	[4.0,  Color(0.72,0.48,0.28), Color(0.65,0.48,0.32), 0.022, 0.40, Color(0.52,0.38,0.22), 0.35, Color(1.00,0.70,0.40), 0.45, 0.08],  # Mañana
	[8.0,  Color(0.45,0.62,0.82), Color(0.52,0.60,0.70), 0.015, 0.60, Color(0.45,0.48,0.44), 0.55, Color(1.00,0.96,0.82), 0.85, 0.14],  # Día
	[16.0, Color(0.68,0.32,0.12), Color(0.60,0.36,0.20), 0.025, 0.42, Color(0.46,0.24,0.12), 0.38, Color(1.00,0.48,0.18), 0.55, 0.08],  # Tarde
	[20.0, Color(0.05,0.06,0.16), Color(0.07,0.09,0.20), 0.030, 0.20, Color(0.09,0.10,0.20), 0.14, Color(0.60,0.65,1.00), 0.00, 0.02],  # Noche
	[28.0, Color(0.72,0.48,0.28), Color(0.65,0.48,0.32), 0.022, 0.40, Color(0.52,0.38,0.22), 0.35, Color(1.00,0.70,0.40), 0.45, 0.08],  # Mañana (wrap)
]

const TRANSITION_DURATION := 2.0

var world_env: WorldEnvironment
var sun: DirectionalLight3D
var fill: DirectionalLight3D

var _period_idx: int = -1
var _transition_t: float = 1.0
var _from_kf: Array = []
var _to_kf: Array = []


func _ready() -> void:
	_setup_environment()
	GameState.clock_changed.connect(_update_lighting)
	_update_lighting(GameState.time_of_day_hours, GameState.current_day)


func _exit_tree() -> void:
	if GameState.clock_changed.is_connected(_update_lighting):
		GameState.clock_changed.disconnect(_update_lighting)


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.fog_enabled = true
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.transform = Transform3D(
		Basis(Vector3(0.866, -0.354, 0.354), Vector3(0.0, 0.707, 0.707), Vector3(-0.5, -0.612, 0.612)),
		Vector3(0, 10, 0))
	sun.shadow_enabled = true
	add_child(sun)

	fill = DirectionalLight3D.new()
	fill.transform = Transform3D(
		Basis(Vector3(-0.866, -0.2, -0.46), Vector3(0.0, 0.917, -0.4), Vector3(0.5, -0.346, -0.795)),
		Vector3(0, 8, 0))
	fill.shadow_enabled = false
	add_child(fill)


func _process(delta: float) -> void:
	if _transition_t >= 1.0:
		return
	_transition_t = minf(_transition_t + delta / TRANSITION_DURATION, 1.0)
	_apply_kf_lerp(_from_kf, _to_kf, _transition_t)


func _get_period_idx(hour: float) -> int:
	var h := hour if hour >= 4.0 else hour + 24.0
	for i in range(LIGHTING_KF.size() - 1):
		if h >= (LIGHTING_KF[i][0] as float) and h < (LIGHTING_KF[i + 1][0] as float):
			return i
	return 0


func _update_lighting(current_hour: float, _day: int) -> void:
	var new_idx := _get_period_idx(current_hour)
	if new_idx == _period_idx:
		return
	var is_init := _period_idx < 0
	_from_kf = LIGHTING_KF[maxi(_period_idx, 0)]
	_period_idx = new_idx
	_to_kf = LIGHTING_KF[new_idx]
	if is_init:
		_transition_t = 1.0
		_apply_kf(_to_kf)
	elif _transition_t < 1.0:
		_from_kf = _snapshot_lighting()
		_transition_t = 0.0
	else:
		_transition_t = 0.0


func _apply_kf(kf: Array) -> void:
	var env := world_env.environment
	env.background_color     = kf[1] as Color
	env.fog_light_color      = kf[2] as Color
	env.fog_density          = kf[3] as float
	env.fog_light_energy     = kf[4] as float
	env.ambient_light_color  = kf[5] as Color
	env.ambient_light_energy = kf[6] as float
	var sun_energy: float    = kf[8] as float
	sun.light_color    = kf[7] as Color
	sun.light_energy   = sun_energy
	sun.shadow_enabled = sun_energy > 0.05
	fill.light_energy  = kf[9] as float


func _apply_kf_lerp(a: Array, b: Array, t: float) -> void:
	var env := world_env.environment
	env.background_color     = (a[1] as Color).lerp(b[1] as Color, t)
	env.fog_light_color      = (a[2] as Color).lerp(b[2] as Color, t)
	env.fog_density          = lerpf(a[3] as float, b[3] as float, t)
	env.fog_light_energy     = lerpf(a[4] as float, b[4] as float, t)
	env.ambient_light_color  = (a[5] as Color).lerp(b[5] as Color, t)
	env.ambient_light_energy = lerpf(a[6] as float, b[6] as float, t)
	var sun_energy: float    = lerpf(a[8] as float, b[8] as float, t)
	sun.light_color    = (a[7] as Color).lerp(b[7] as Color, t)
	sun.light_energy   = sun_energy
	sun.shadow_enabled = sun_energy > 0.05
	fill.light_energy  = lerpf(a[9] as float, b[9] as float, t)


func _snapshot_lighting() -> Array:
	var env := world_env.environment
	return [
		0.0,
		env.background_color,
		env.fog_light_color,
		env.fog_density,
		env.fog_light_energy,
		env.ambient_light_color,
		env.ambient_light_energy,
		sun.light_color,
		sun.light_energy,
		fill.light_energy,
	]


## Para la cinemática de evolución: frena cualquier transición en curso antes
## de que tome control manual de sun/fill/environment.
func freeze_transition() -> void:
	_transition_t = 1.0


## Para la cinemática de evolución: vuelve a aplicar la luz del período actual
## después de que la cinemática suelta el control manual.
func reapply_current_period() -> void:
	_apply_kf(_to_kf)
