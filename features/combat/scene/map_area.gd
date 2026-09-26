extends Node3D

signal position_selected(pos: Vector2)
signal player_anim_finished
signal enemy_anim_finished
signal enemy_reached_target
## Se prendió fuego el árbol al que está trepado el jugador (ya bajó al pie).
signal player_knocked_off_tree(burning: bool)

# ── World bounds ──────────────────────────────────────────────────────────────
const WORLD_W := 30.0
const WORLD_H := 30.0

# ── Positions (XZ world space) ────────────────────────────────────────────────
var player_pos := Vector2(3.0, 27.0)
var enemy_pos  := Vector2(27.0, 3.0)

# ── Selection state ───────────────────────────────────────────────────────────
var selected_move_range   := 0.0
var selected_attack_range := 0.0
var grenade_landing       := Vector2(-1.0, -1.0)
var grenade_aoe_radius    := 0.0
var selected_trap_range   := 0.0
var trap_zones: Array = []
var _trap_visuals: Array = []
var _enemy_move_pending  := false
var _enemy_waypoints: Array[Vector3] = []
var puddle_zones: Array[Dictionary] = []
var _puddle_visuals: Array[MeshInstance3D] = []
var _next_puddle_id := 0
var enemy_hp := 35

# ── Elevation ─────────────────────────────────────────────────────────────────
# 0 = suelo, 1 = encima de una plataforma
var player_elevation: int = 0
var enemy_elevation:  int = 0

# ── Pathfinding ───────────────────────────────────────────────────────────────
const PATH_CELL    := 0.5
var _last_path: Array[Vector2] = []
var _last_path_cost: float = 0.0
## Casillas alcanzables del movimiento en curso (ver CombatGrid.reachable).
var _move_reach: Dictionary = {}
var _player_waypoints: Array[Vector3] = []
var _move_origin := Vector2.ZERO
## Los caminos en 8 direcciones son hasta un 8,24 % más largos que la línea recta
## (peor caso a 22,5°). Con este margen, en terreno abierto el alcance es un
## círculo exacto; rodear obstáculos igual cuesta de verdad.
const PATH_SLACK := 1.0824
## Caché de _pos_blocked por casilla: los obstáculos no cambian durante el combate.
## Clave: Vector3i(cell.x, cell.y, elevation) dentro de un diccionario por margen.
var _blocked_cache: Dictionary = {}
## Altura del terreno por casilla (NAN = sin calcular). El terreno es estático.
var _height_cache := PackedFloat32Array()
## Precarga de los cachés de la grilla, repartida en varios cuadros (-1 = terminada).
var _warm_next := 0
const WARM_CELLS_PER_FRAME := 1500

# ── Obstacles ─────────────────────────────────────────────────────────────────
# type "solid"  → bloquea movimiento Y línea de visión
# type "rock"   → bloquea movimiento, LOS pasa a través (piedra pequeña)
# type "bridge" → movimiento permitido por debajo, LOS bloqueada (puente)
# "module": true → es un módulo: se puede romper, golpear y saltar desde él
#                  (las piedras chicas; las cartas crean más, ver build_modules)
var solid_obstacles := [
	{"pos": Vector2(14.0, 19.0), "radius": 1.5,                            "type": "solid"},
	{"pos": Vector2(21.0,  9.0), "box": Vector2(3.0, 2.5),                 "type": "solid"},
	{"pos": Vector2(7.0,  14.0), "radius": 0.55,                           "type": "rock", "module": true},
	{"pos": Vector2(15.0, 15.0), "radius": 0.5,                            "type": "rock", "module": true},
	{"pos": Vector2(23.0, 17.0), "radius": 0.55,                           "type": "rock", "module": true},
	{"pos": Vector2(13.0, 24.0), "box": Vector2(5.0, 2.0),                 "type": "bridge"},
	{"pos": Vector2(17.0,  6.0), "box": Vector2(2.0, 5.0),                 "type": "bridge"},
	# tree: bloquea movimiento y línea de visión; se puede trepar (línea "tree_climb")
	{"pos": Vector2(5.0, 24.0),  "radius": 0.6,                            "type": "tree"},
	{"pos": Vector2(22.0, 5.0),  "radius": 0.6,                            "type": "tree"},
	{"pos": Vector2(20.0, 22.0), "radius": 0.6,                            "type": "tree"},
	# platform: caja elevada con rampas. se sube por las rampas, bloquea LOS desde el suelo
	{"pos": Vector2(8.0,  10.0), "box": Vector2(5.0, 5.0),                "type": "platform",
	 "ramps": [{"side": "south", "width": 2.5}, {"side": "east", "width": 2.5}]},
]

const PLATFORM_HEIGHT := 1.5
const TREE_HEIGHT     := 2.4
const RAMP_DEPTH      := 1.5

# ── Visual ────────────────────────────────────────────────────────────────────
## Alturas de los resaltados sobre el suelo: la sombra está en 0.02.
const HIGHLIGHT_Y := 0.03
const HOVER_Y := 0.04
## Cuánto más allá de la huella un clic sigue contando como "sobre el personaje".
const CLICK_MARGIN := 0.6

var _move_disc:       MeshInstance3D
var _player_circle:   MeshInstance3D
var _attack_disc:     MeshInstance3D
var _grenade_disc:    MeshInstance3D
var _trap_disc:       MeshInstance3D
var _dest_marker:     MeshInstance3D
var _path_highlight:  MeshInstance3D
var _hover_cell:      MeshInstance3D
var _player_shadow:        MeshInstance3D
var _enemy_shadow:         MeshInstance3D
var _player_shadow_radius: float = 0.4
var _enemy_shadow_radius:  float = 0.4
var _player_body:         Node3D
var _player_bodies:       Dictionary = {}
var _player_current_anim: String = ""
var _player_rotate_speed: float = 8.0
var _enemy_body:          Node3D
var _enemy_bodies:        Dictionary = {}
var _enemy_current_anim:  String = ""
var _enemy_rotate_speed:  float = 8.0
var _enemy_fallback_mesh: MeshInstance3D

const _PRIORITY_ANIMS       := ["attack", "range", "damage", "die"]
const _ENEMY_PRIORITY_ANIMS := ["attack", "damage"]

# ── Movement animation ────────────────────────────────────────────────────────
const ACTOR_MOVE_SPEED  := 12.0
const MIN_SEPARATION    := 0.8

var _player_target: Vector3
var _enemy_target:  Vector3

var _enemy_highlight:     MeshInstance3D
var _self_highlight:      MeshInstance3D
var _enemy_hover:         MeshInstance3D
var _self_hover:          MeshInstance3D

var _jump_disc:               MeshInstance3D
var _jump_landing_disc:       MeshInstance3D
var _push_disc:               MeshInstance3D
var _push_enemy_disc:         MeshInstance3D
var _puddle_disc:             MeshInstance3D
var _puddle_preview:          MeshInstance3D
var _puddle_preview_effect:   String  = "wet"
var _puddle_preview_radius:   float   = 1.0
var _puddle_throw_range:      float   = 0.0
var _puddle_preview_last_pos: Vector2 = Vector2(-999.0, -999.0)
var _trap_preview:            MeshInstance3D
var _trap_preview_radius:     float   = 1.0
var _trap_preview_last_pos:   Vector2 = Vector2(-999.0, -999.0)

var _overwatch_zone:              MeshInstance3D
var _overwatch_preview_disc:      MeshInstance3D
var _overwatch_selection_active:  bool    = false
var _overwatch_selection_range:   float   = 0.0
var _overwatch_selection_angle:   float   = 10.0
var _overwatch_preview_last_dir:  Vector2 = Vector2.ZERO
var _jump_rock_markers:       Array[MeshInstance3D] = []
var _jump_selected_marker:    MeshInstance3D
var _jump_rocks_in_range:     Array[Dictionary] = []

# ── Init ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_setup_ground()
	_move_disc       = _make_disc(Color(0.2,  0.45, 0.85, 0.35))
	_player_circle   = _make_disc(Color(0.6,  0.85, 1.0,  0.50))
	_attack_disc     = _make_disc(Color(0.9,  0.35, 0.1,  0.40))
	_grenade_disc    = _make_disc(Color(0.9,  0.8,  0.1,  0.45))
	_trap_disc       = _make_disc(Color(0.75, 0.4,  0.75, 0.35))
	_dest_marker     = _make_disc(Color(0.2,  0.95, 0.3,  0.80))
	_path_highlight  = _make_disc(Color(0.3,  0.95, 0.45, 0.70))
	_hover_cell      = _make_disc(Color(1.0,  1.0,  1.0,  0.55))
	_player_shadow   = _make_disc(Color(0.3,  0.6,  1.0,  0.35))
	_enemy_shadow    = _make_disc(Color(1.0,  0.3,  0.2,  0.35))

	_jump_disc         = _make_disc(Color(0.3, 0.9, 0.4, 0.35))
	_jump_landing_disc = _make_disc(Color(0.95, 0.5, 0.1, 0.40))
	_push_disc         = _make_disc(Color(0.9, 0.2, 0.6, 0.40))
	_push_enemy_disc   = _make_disc(Color(1.0, 0.5, 0.1, 0.70))
	_puddle_disc       = _make_disc(Color(0.1, 0.5, 0.9, 0.45))
	_puddle_preview    = MeshInstance3D.new()
	_puddle_preview.visible = false
	add_child(_puddle_preview)
	_trap_preview      = MeshInstance3D.new()
	_trap_preview.visible = false
	add_child(_trap_preview)

	_overwatch_zone = MeshInstance3D.new()
	_overwatch_zone.visible = false
	add_child(_overwatch_zone)
	_overwatch_preview_disc = MeshInstance3D.new()
	_overwatch_preview_disc.visible = false
	add_child(_overwatch_preview_disc)

	# Resaltados en casillas. Los de personajes pintan las casillas de su huella
	# (la "sombra"), un poco por encima de ella; el hover va más arriba y más brillante.
	_jump_selected_marker = _make_highlight_disc(Color(0.9, 1.0, 0.2))
	_enemy_highlight      = _make_highlight_disc(Color(1.0, 0.25, 0.1))
	_self_highlight       = _make_highlight_disc(Color(0.2, 0.75, 1.0))
	_enemy_hover          = _make_highlight_disc(Color(1.0, 0.85, 0.2))
	_self_hover           = _make_highlight_disc(Color(0.6, 1.0, 1.0))

	_setup_obstacles()
	_setup_actors()

func _setup_obstacles() -> void:
	var solid_mat := StandardMaterial3D.new()
	solid_mat.albedo_color = Color(0.30, 0.25, 0.20)
	solid_mat.roughness    = 0.9

	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.50, 0.47, 0.43)
	rock_mat.roughness    = 0.95

	var bridge_mat := StandardMaterial3D.new()
	bridge_mat.albedo_color  = Color(0.55, 0.40, 0.22, 0.80)
	bridge_mat.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
	bridge_mat.roughness     = 0.7

	for obs in solid_obstacles:
		var pos: Vector2      = obs["pos"]
		var obs_type: String  = obs.get("type", "solid")
		var mi               := MeshInstance3D.new()
		match obs_type:
			"platform":
				var size: Vector2 = obs["box"]
				var plat_mat := StandardMaterial3D.new()
				plat_mat.albedo_color = Color(0.35, 0.30, 0.22)
				plat_mat.roughness    = 0.8
				var box := BoxMesh.new()
				box.size = Vector3(size.x, PLATFORM_HEIGHT, size.y)
				mi.mesh  = box
				mi.position = Vector3(pos.x, PLATFORM_HEIGHT * 0.5, pos.y)
				mi.material_override = plat_mat
				add_child(mi)
				# rampas
				var ramp_mat := StandardMaterial3D.new()
				ramp_mat.albedo_color = Color(0.45, 0.38, 0.26)
				ramp_mat.roughness    = 0.85
				ramp_mat.cull_mode    = BaseMaterial3D.CULL_DISABLED
				var h := size * 0.5
				for ramp in obs.get("ramps", []):
					var rw: float = ramp.get("width", 2.0) * 0.5
					var ramp_mi  := MeshInstance3D.new()
					var verts    := PackedVector3Array()
					var indices  := PackedInt32Array()
					match ramp["side"]:
						"south":
							# Top edge at platform edge, base extends outward to ground
							verts.append(Vector3(pos.x - rw, PLATFORM_HEIGHT, pos.y + h.y))
							verts.append(Vector3(pos.x + rw, PLATFORM_HEIGHT, pos.y + h.y))
							verts.append(Vector3(pos.x + rw, 0.0,             pos.y + h.y + RAMP_DEPTH))
							verts.append(Vector3(pos.x - rw, 0.0,             pos.y + h.y + RAMP_DEPTH))
						"north":
							verts.append(Vector3(pos.x - rw, 0.0,             pos.y - h.y - RAMP_DEPTH))
							verts.append(Vector3(pos.x + rw, 0.0,             pos.y - h.y - RAMP_DEPTH))
							verts.append(Vector3(pos.x + rw, PLATFORM_HEIGHT, pos.y - h.y))
							verts.append(Vector3(pos.x - rw, PLATFORM_HEIGHT, pos.y - h.y))
						"east":
							verts.append(Vector3(pos.x + h.x,              PLATFORM_HEIGHT, pos.y - rw))
							verts.append(Vector3(pos.x + h.x + RAMP_DEPTH, 0.0,             pos.y - rw))
							verts.append(Vector3(pos.x + h.x + RAMP_DEPTH, 0.0,             pos.y + rw))
							verts.append(Vector3(pos.x + h.x,              PLATFORM_HEIGHT, pos.y + rw))
						"west":
							verts.append(Vector3(pos.x - h.x - RAMP_DEPTH, 0.0,             pos.y - rw))
							verts.append(Vector3(pos.x - h.x,              PLATFORM_HEIGHT, pos.y - rw))
							verts.append(Vector3(pos.x - h.x,              PLATFORM_HEIGHT, pos.y + rw))
							verts.append(Vector3(pos.x - h.x - RAMP_DEPTH, 0.0,             pos.y + rw))
					indices.append_array([0,1,2, 0,2,3])
					var arr := []; arr.resize(Mesh.ARRAY_MAX)
					arr[Mesh.ARRAY_VERTEX] = verts; arr[Mesh.ARRAY_INDEX] = indices
					var rmesh := ArrayMesh.new()
					rmesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
					ramp_mi.mesh = rmesh
					ramp_mi.material_override = ramp_mat
					add_child(ramp_mi)
				continue
			"bridge":
				var size: Vector2 = obs["box"]
				var box          := BoxMesh.new()
				box.size          = Vector3(size.x, 0.22, size.y)
				mi.mesh           = box
				mi.position       = Vector3(pos.x, 0.9, pos.y)
				mi.material_override = bridge_mat
			"tree":
				var r: float = obs["radius"]
				var trunk := CylinderMesh.new()
				trunk.top_radius = r * 0.45
				trunk.bottom_radius = r * 0.6
				trunk.height = TREE_HEIGHT
				mi.mesh = trunk
				mi.position = Vector3(pos.x, TREE_HEIGHT * 0.5, pos.y)
				var trunk_mat := StandardMaterial3D.new()
				trunk_mat.albedo_color = Color(0.36, 0.24, 0.14)
				mi.material_override = trunk_mat
				var canopy := MeshInstance3D.new()
				var sphere := SphereMesh.new()
				sphere.radius = r * 2.2
				sphere.height = r * 3.2
				canopy.mesh = sphere
				canopy.position = Vector3(0.0, TREE_HEIGHT * 0.5, 0.0)
				var leaf_mat := StandardMaterial3D.new()
				leaf_mat.albedo_color = Color(0.18, 0.45, 0.2)
				canopy.material_override = leaf_mat
				mi.add_child(canopy)
				obs["canopy"] = canopy
			"rock":
				var r: float      = obs["radius"]
				var cyl          := CylinderMesh.new()
				cyl.top_radius    = r * 0.70
				cyl.bottom_radius = r
				cyl.height        = r * 0.9
				mi.mesh           = cyl
				mi.position       = Vector3(pos.x, cyl.height * 0.5, pos.y)
				mi.material_override = rock_mat
			_: # solid
				if obs.has("box"):
					var size: Vector2 = obs["box"]
					var box          := BoxMesh.new()
					box.size          = Vector3(size.x, size.x * 1.5, size.y)
					mi.mesh           = box
					mi.position       = Vector3(pos.x, box.size.y * 0.5, pos.y)
				else:
					var r: float      = obs["radius"]
					var cyl          := CylinderMesh.new()
					cyl.top_radius    = r
					cyl.bottom_radius = r
					cyl.height        = r * 2.5
					mi.mesh           = cyl
					mi.position       = Vector3(pos.x, cyl.height * 0.5, pos.y)
				mi.material_override = solid_mat
		add_child(mi)
		obs["node"] = mi

func _setup_ground() -> void:
	var mi    := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size  = Vector2(WORLD_W + 4.0, WORLD_H + 4.0)
	mi.mesh     = plane
	mi.position = Vector3(WORLD_W / 2.0, -0.02, WORLD_H / 2.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.16, 0.20)
	mi.material_override = mat
	add_child(mi)

func _make_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func _make_disc(color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var fill_mat := _make_mat(Color(color.r, color.g, color.b, color.a * 0.5))
	var bord_mat := _make_mat(Color(
		minf(color.r + 0.3, 1.0),
		minf(color.g + 0.3, 1.0),
		minf(color.b + 0.3, 1.0),
		minf(color.a + 0.3, 1.0)))
	mi.set_meta("fill_mat", fill_mat)
	mi.set_meta("bord_mat", bord_mat)
	mi.visible = false
	add_child(mi)
	return mi

## Como _make_disc pero casi opaco: para resaltar personajes u objetos puntuales,
## que tienen que verse aunque el modelo tape parte de las casillas.
func _make_highlight_disc(color: Color) -> MeshInstance3D:
	var mi := _make_disc(color)
	mi.set_meta("fill_mat", _make_mat(Color(color, 0.85)))
	mi.set_meta("bord_mat", _make_mat(Color(color.lightened(0.45), 1.0)))
	return mi

func _show_disc(mi: MeshInstance3D, center: Vector2, radius: float, _unused: int = 0) -> void:
	_build_tile_disc(mi, center, radius, 0.0, 0.02)

func _show_disc_ring(mi: MeshInstance3D, center: Vector2, radius: float, inner: float) -> void:
	_build_tile_disc(mi, center, radius, inner, 0.02)

func _build_tile_disc(mi: MeshInstance3D, center: Vector2, radius: float, inner_radius: float, y: float, exclusions: Array = []) -> void:
	const CELL   := 0.08
	const BORDER := 0.010
	var half     := CELL * 0.5

	var fill_v := PackedVector3Array()
	var fill_i := PackedInt32Array()
	var bord_v := PackedVector3Array()
	var bord_i := PackedInt32Array()

	var min_gx := int(floor((center.x - radius) / CELL))
	var max_gx := int(ceil( (center.x + radius) / CELL))
	var min_gy := int(floor((center.y - radius) / CELL))
	var max_gy := int(ceil( (center.y + radius) / CELL))

	for gx in range(min_gx, max_gx + 1):
		for gy in range(min_gy, max_gy + 1):
			var cx := (gx + 0.5) * CELL
			var cy := (gy + 0.5) * CELL
			var px := clampf(center.x, cx - half, cx + half)
			var py := clampf(center.y, cy - half, cy + half)
			if Vector2(px, py).distance_to(center) > radius:
				continue
			var d := Vector2(cx, cy).distance_to(center)
			if inner_radius > 0.0 and d < inner_radius:
				continue
			var cell_pos := Vector2(cx, cy)
			var excluded := false
			for ex in exclusions:
				if cell_pos.distance_to(ex["pos"]) <= ex["radius"]:
					excluded = true; break
			if excluded: continue

			# fill quad (slightly inset so border is visible)
			var fi := fill_v.size()
			var f  := BORDER
			fill_v.append(Vector3(cx - half + f, y,        cy - half + f))
			fill_v.append(Vector3(cx + half - f, y,        cy - half + f))
			fill_v.append(Vector3(cx + half - f, y,        cy + half - f))
			fill_v.append(Vector3(cx - half + f, y,        cy + half - f))
			fill_i.append_array([fi, fi+1, fi+2, fi, fi+2, fi+3])

			# border strips (top, bottom, left, right)
			var strips := [
				[cx-half, cy-half,        cx+half,        cy-half+BORDER],
				[cx-half, cy+half-BORDER, cx+half,        cy+half],
				[cx-half, cy-half+BORDER, cx-half+BORDER, cy+half-BORDER],
				[cx+half-BORDER, cy-half+BORDER, cx+half, cy+half-BORDER],
			]
			for s in strips:
				var x0: float = s[0]; var z0: float = s[1]
				var x1: float = s[2]; var z1: float = s[3]
				var bi := bord_v.size()
				bord_v.append(Vector3(x0, y + 0.001, z0))
				bord_v.append(Vector3(x1, y + 0.001, z0))
				bord_v.append(Vector3(x1, y + 0.001, z1))
				bord_v.append(Vector3(x0, y + 0.001, z1))
				bord_i.append_array([bi, bi+1, bi+2, bi, bi+2, bi+3])

	var mesh := ArrayMesh.new()
	var fa := []; fa.resize(Mesh.ARRAY_MAX)
	fa[Mesh.ARRAY_VERTEX] = fill_v; fa[Mesh.ARRAY_INDEX] = fill_i
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, fa)
	var ba := []; ba.resize(Mesh.ARRAY_MAX)
	ba[Mesh.ARRAY_VERTEX] = bord_v; ba[Mesh.ARRAY_INDEX] = bord_i
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ba)

	mi.mesh = mesh
	mi.set_surface_override_material(0, mi.get_meta("fill_mat") if mi.has_meta("fill_mat") else null)
	mi.set_surface_override_material(1, mi.get_meta("bord_mat") if mi.has_meta("bord_mat") else null)
	mi.visible = fill_v.size() > 0

## Pinta las casillas de la huella de un personaje (las mismas de su sombra).
func _show_footprint(mi: MeshInstance3D, center: Vector2, radius: float, y := HIGHLIGHT_Y) -> void:
	_build_tile_disc(mi, center, radius, 0.0, y)

func _setup_actors() -> void:
	_player_body = Node3D.new()
	add_child(_player_body)

	_enemy_body = Node3D.new()
	var fallback_mi := MeshInstance3D.new()
	var fallback := CapsuleMesh.new()
	fallback.radius = 0.4
	fallback.height = 1.2
	fallback_mi.mesh = fallback
	_enemy_fallback_mesh = fallback_mi
	_enemy_body.add_child(fallback_mi)
	add_child(_enemy_body)

	_player_target = Vector3(player_pos.x, 0.0, player_pos.y)
	_enemy_target  = Vector3(enemy_pos.x,   0.0, enemy_pos.y)
	_player_body.position = _player_target
	_enemy_body.position  = _enemy_target

func setup_player(data: YounData) -> void:
	if not data:
		return
	_player_shadow_radius = data.combat_footprint_radius()
	_player_head_height = _head_height(data)
	for child in _player_body.get_children():
		child.queue_free()
	_player_bodies.clear()
	_player_current_anim = ""
	_player_rotate_speed = data.rotate_speed

	var mat: StandardMaterial3D = null
	if data.texture:
		mat = StandardMaterial3D.new()
		mat.albedo_texture = data.texture
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var scene_map := {
		"idle":   data.scene_idle,
		"walk":   data.scene_walk,
		"run":    data.scene_run,
		"attack": data.scene_attack,
		"range":  data.scene_range,
		"damage": data.scene_damage,
		"die":    data.scene_die,
	}
	for key in scene_map:
		var packed: PackedScene = scene_map[key]
		if not packed:
			continue
		var body: Node3D = packed.instantiate()
		body.scale = Vector3.ONE * data.mesh_scale
		body.position.y = 0.0
		body.rotation.y = data.mesh_rotation_y
		body.visible = false
		if mat:
			for mesh in _find_meshes(body):
				mesh.material_override = mat
		_player_body.add_child(body)
		_player_bodies[key] = body

	_switch_player_to("idle")

func play_player_anim(anim_key: String) -> void:
	_switch_player_to(anim_key)

func _switch_player_to(anim_key: String) -> void:
	var target := anim_key if anim_key in _player_bodies else "idle"
	var is_priority := anim_key in _PRIORITY_ANIMS
	if is_priority and target != anim_key:
		player_anim_finished.emit.call_deferred()
		return
	if _player_current_anim == target:
		return
	if _player_current_anim in _player_bodies:
		_player_bodies[_player_current_anim].visible = false
	_player_current_anim = target
	if target not in _player_bodies:
		if is_priority:
			player_anim_finished.emit.call_deferred()
		return
	var body: Node3D = _player_bodies[target]
	body.visible = true
	var anim_player := _find_anim_player(body)
	if anim_player:
		var list := anim_player.get_animation_list()
		if not list.is_empty():
			var anim := anim_player.get_animation(list[0])
			if anim:
				anim.loop_mode = Animation.LOOP_NONE if is_priority else Animation.LOOP_LINEAR
			if is_priority:
				anim_player.animation_finished.connect(
					func(_n: StringName) -> void: player_anim_finished.emit(),
					CONNECT_ONE_SHOT
				)
			anim_player.play(list[0])
		elif is_priority:
			player_anim_finished.emit.call_deferred()
	elif is_priority:
		player_anim_finished.emit.call_deferred()

func _find_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_meshes(child))
	return result

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim_player(child)
		if found:
			return found
	return null

func setup_enemy(mesh: Mesh, mesh_scale: float, shadow_radius: float = 0.65) -> void:
	_enemy_shadow_radius = shadow_radius
	if _enemy_fallback_mesh:
		_enemy_fallback_mesh.visible = true
		if mesh:
			_enemy_fallback_mesh.mesh  = mesh
			_enemy_fallback_mesh.scale = Vector3.ONE * mesh_scale

func setup_enemy_youn(data: YounData) -> void:
	if not data:
		return
	_enemy_shadow_radius = data.combat_footprint_radius()
	_enemy_head_height = _head_height(data)
	_enemy_rotate_speed  = data.rotate_speed
	if _enemy_fallback_mesh:
		_enemy_fallback_mesh.visible = false
	for child in _enemy_body.get_children():
		child.queue_free()
	_enemy_bodies.clear()
	_enemy_current_anim = ""

	var mat: StandardMaterial3D = null
	if data.texture:
		mat = StandardMaterial3D.new()
		mat.albedo_texture = data.texture
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var scene_map := {
		"idle":   data.scene_idle,
		"walk":   data.scene_walk,
		"run":    data.scene_run,
		"attack": data.scene_attack,
		"damage": data.scene_damage,
	}
	for key in scene_map:
		var packed: PackedScene = scene_map[key]
		if not packed:
			continue
		var body: Node3D = packed.instantiate()
		body.scale = Vector3.ONE * data.mesh_scale
		body.position.y = 0.0
		body.rotation.y = data.mesh_rotation_y
		body.visible = false
		if mat:
			for mesh_inst in _find_meshes(body):
				mesh_inst.material_override = mat
		_enemy_body.add_child(body)
		_enemy_bodies[key] = body

	if _enemy_bodies.is_empty() and data.mesh and _enemy_fallback_mesh:
		_enemy_fallback_mesh.mesh  = data.mesh
		_enemy_fallback_mesh.scale = Vector3.ONE * data.mesh_scale
		_enemy_fallback_mesh.visible = true
	else:
		_switch_enemy_to("idle")

func play_enemy_anim(anim_key: String) -> void:
	_switch_enemy_to(anim_key)

func _switch_enemy_to(anim_key: String) -> void:
	var is_priority := anim_key in _ENEMY_PRIORITY_ANIMS
	if _enemy_bodies.is_empty():
		if is_priority:
			enemy_anim_finished.emit.call_deferred()
		return
	var target := anim_key if anim_key in _enemy_bodies else "idle"
	if is_priority and target != anim_key:
		enemy_anim_finished.emit.call_deferred()
		return
	if _enemy_current_anim == target and not is_priority:
		return
	if _enemy_current_anim in _enemy_bodies:
		_enemy_bodies[_enemy_current_anim].visible = false
	_enemy_current_anim = target
	if target not in _enemy_bodies:
		if is_priority:
			enemy_anim_finished.emit.call_deferred()
		return
	var body: Node3D = _enemy_bodies[target]
	body.visible = true
	var anim_player := _find_anim_player(body)
	if anim_player:
		var list := anim_player.get_animation_list()
		if not list.is_empty():
			var anim_res := anim_player.get_animation(list[0])
			if anim_res:
				anim_res.loop_mode = Animation.LOOP_NONE if is_priority else Animation.LOOP_LINEAR
			if is_priority:
				anim_player.animation_finished.connect(
					func(_n: StringName) -> void: enemy_anim_finished.emit(),
					CONNECT_ONE_SHOT
				)
			anim_player.play(list[0])
		elif is_priority:
			enemy_anim_finished.emit.call_deferred()
	elif is_priority:
		enemy_anim_finished.emit.call_deferred()

func _update_actor_positions() -> void:
	var player_y: float = 0.0
	if player_elevation > 0:
		# On the platform interior: full height. On the ramp zone: at ground level.
		for obs in solid_obstacles:
			if obs.get("type", "solid") != "platform": continue
			var p: Vector2 = obs["pos"]
			var hh: Vector2 = obs["box"] * 0.5
			if abs(player_pos.x - p.x) <= hh.x and abs(player_pos.y - p.y) <= hh.y:
				player_y = PLATFORM_HEIGHT
				break
	_player_target = Vector3(player_pos.x, player_y, player_pos.y)
	if not _climbed_tree.is_empty():
		# Arriba del árbol: solo cambia lo que se ve; la posición lógica queda al pie.
		var t: Vector2 = _climbed_tree["pos"]
		_player_target = Vector3(t.x, TREE_HEIGHT, t.y)
	var enemy_y: float = float(enemy_elevation) * PLATFORM_HEIGHT
	_enemy_target  = Vector3(enemy_pos.x, enemy_y, enemy_pos.y)

# ── Input ─────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera: return

	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var from := camera.project_ray_origin(event.position)
		var dir  := camera.project_ray_normal(event.position)
		if abs(dir.y) < 0.001: return
		var pos := _ray_to_terrain(from, dir)
		_last_click_pos = pos  # si se está confirmando, cambia el lugar elegido
		position_selected.emit(pos)

func _process(delta: float) -> void:
	_warm_grid_caches()
	var camera := get_viewport().get_camera_3d()
	if camera:
		_update_hover(get_viewport().get_mouse_position(), camera)
	var step := ACTOR_MOVE_SPEED * delta

	var prev_pos := _player_body.position
	var player_goal := _player_target
	if not _player_waypoints.is_empty():
		player_goal = _player_waypoints[0]
	_player_body.position = _player_body.position.move_toward(player_goal, step)
	if not _player_waypoints.is_empty() and _player_body.position.distance_to(player_goal) < 0.05:
		_player_waypoints.pop_front()
	var dist_moved := prev_pos.distance_to(_player_body.position)

	if _player_current_anim not in _PRIORITY_ANIMS:
		var face_dir: Vector3
		if dist_moved > 0.001:
			face_dir = player_goal - prev_pos
			play_player_anim("run" if "run" in _player_bodies else "walk")
		else:
			face_dir = _enemy_body.position - _player_body.position
			play_player_anim("idle")
		face_dir.y = 0.0
		if face_dir.length() > 0.001:
			var target_angle := atan2(face_dir.x, face_dir.z)
			_player_body.rotation.y = lerp_angle(_player_body.rotation.y, target_angle, _player_rotate_speed * delta)

	var prev_enemy := _enemy_body.position
	var _current_enemy_target := _enemy_target
	if not _enemy_waypoints.is_empty():
		_current_enemy_target = _enemy_waypoints[0]
		_enemy_body.position = _enemy_body.position.move_toward(_current_enemy_target, step)
		if _enemy_body.position.distance_to(_current_enemy_target) < 0.05:
			_enemy_waypoints.pop_front()
	else:
		_enemy_body.position = _enemy_body.position.move_toward(_enemy_target, step)
	var enemy_moved := prev_enemy.distance_to(_enemy_body.position)

	var to_player := _player_body.position - _enemy_body.position
	to_player.y = 0.0
	if to_player.length() > 0.001:
		_enemy_body.rotation.y = lerp_angle(
			_enemy_body.rotation.y, atan2(to_player.x, to_player.z), _enemy_rotate_speed * delta)

	if not _enemy_bodies.is_empty() and _enemy_current_anim not in _ENEMY_PRIORITY_ANIMS:
		if enemy_moved > 0.001:
			_switch_enemy_to("run" if "run" in _enemy_bodies else "walk")
		else:
			_switch_enemy_to("idle")

	if _enemy_move_pending and _enemy_body.position.distance_to(_enemy_target) < 0.05:
		_enemy_move_pending = false
		enemy_reached_target.emit()

	_place_status_labels()
	_show_disc(_player_shadow, Vector2(_player_body.position.x, _player_body.position.z), _player_shadow_radius)
	_show_disc(_enemy_shadow,  Vector2(_enemy_body.position.x,  _enemy_body.position.z),  _enemy_shadow_radius)

## Mientras se confirma una acción la vista previa (charco, cono, área...) queda
## fija en el lugar elegido en vez de seguir al mouse.
var _hover_locked := false
var _last_click_pos := Vector2.ZERO

func lock_hover_at_last_click() -> void:
	_hover_locked = true

func unlock_hover() -> void:
	_hover_locked = false

# ── Estados sobre los personajes ──────────────────────────────────────────────
## Texto con los estados de cada uno (fuego, mojado, escudos...) flotando sobre
## su cabeza. Lo arma combat.gd (set_status_texts) cada vez que cambia la UI.
const DEFAULT_HEAD_HEIGHT := 1.6
const STATUS_LABEL_GAP := 0.35
var _player_head_height := DEFAULT_HEAD_HEIGHT
var _enemy_head_height := DEFAULT_HEAD_HEIGHT
var _player_status_label: Label3D
var _enemy_status_label: Label3D

## Misma altura que usa la burbuja de emociones en el mundo.
static func _head_height(data: YounData) -> float:
	var h := data.body_height * data.mesh_scale + data.mesh_y_offset
	return h if h > 0.3 else DEFAULT_HEAD_HEIGHT

func set_status_texts(player_text: String, enemy_text: String) -> void:
	if _player_status_label == null:
		_player_status_label = _make_status_label(Color(0.75, 0.95, 1.0))
		_enemy_status_label = _make_status_label(Color(1.0, 0.85, 0.75))
	_player_status_label.text = player_text
	_enemy_status_label.text = enemy_text
	_place_status_labels()

func _make_status_label(color: Color) -> Label3D:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 40
	label.outline_size = 10
	label.modulate = color
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.width = 520.0
	label.pixel_size = 0.004
	add_child(label)
	return label

func _place_status_labels() -> void:
	if _player_status_label == null or _player_body == null or _enemy_body == null:
		return
	_player_status_label.position = _player_body.position + Vector3(0.0, _player_head_height + STATUS_LABEL_GAP, 0.0)
	_enemy_status_label.position = _enemy_body.position + Vector3(0.0, _enemy_head_height + STATUS_LABEL_GAP, 0.0)

func _update_hover(screen_pos: Vector2, camera: Camera3D) -> void:
	var any_disc   := _move_disc.visible or _attack_disc.visible \
		or _trap_disc.visible or _grenade_disc.visible \
		or _jump_disc.visible or _jump_landing_disc.visible \
		or _push_disc.visible or _push_enemy_disc.visible \
		or _puddle_disc.visible
	var any_target := _enemy_highlight.visible or _self_highlight.visible or _attack_disc.visible
	if not any_disc and not any_target and not _overwatch_selection_active:
		_hover_cell.visible             = false
		_enemy_hover.visible            = false
		_self_hover.visible             = false
		_overwatch_preview_disc.visible = false
		return
	var from := camera.project_ray_origin(screen_pos)
	var dir  := camera.project_ray_normal(screen_pos)
	if abs(dir.y) < 0.001 and not _hover_locked:
		_hover_cell.visible             = false
		_enemy_hover.visible            = false
		_self_hover.visible             = false
		_overwatch_preview_disc.visible = false
		return
	var pos := _last_click_pos if _hover_locked else _ray_to_terrain(from, dir)
	if any_disc:
		_show_single_cell(_hover_cell, pos)
	else:
		_hover_cell.visible = false
	_enemy_hover.visible = (_enemy_highlight.visible or _attack_disc.visible) and is_click_on_enemy(pos)
	_self_hover.visible  = _self_highlight.visible and is_click_on_player(pos)

	if _puddle_disc.visible:
		var in_range := pos.distance_to(player_pos) <= _puddle_throw_range \
			and not _tile_in_obstacle(pos, player_elevation)
		if in_range:
			var snapped := Vector2(round(pos.x * 2.0) / 2.0, round(pos.y * 2.0) / 2.0)
			if snapped.distance_to(_puddle_preview_last_pos) > 0.01:
				_puddle_preview_last_pos = snapped
				var base := _puddle_base_color(_puddle_preview_effect)
				_puddle_preview.set_meta("fill_mat", _make_mat(Color(base.r, base.g, base.b, 0.22)))
				_puddle_preview.set_meta("bord_mat", _make_mat(Color(
					minf(base.r + 0.2, 1.0), minf(base.g + 0.2, 1.0), minf(base.b + 0.2, 1.0), 0.60)))
				_build_tile_disc(_puddle_preview, snapped, _puddle_preview_radius, 0.0, 0.015)
			_puddle_preview.visible = true
		else:
			_puddle_preview.visible = false
	else:
		_puddle_preview.visible = false

	if _trap_disc.visible:
		var in_range := pos.distance_to(player_pos) <= selected_trap_range \
			and not _tile_in_obstacle(pos, player_elevation)
		if in_range:
			var snapped := Vector2(round(pos.x * 2.0) / 2.0, round(pos.y * 2.0) / 2.0)
			if snapped.distance_to(_trap_preview_last_pos) > 0.01:
				_trap_preview_last_pos = snapped
				_trap_preview.set_meta("fill_mat", _make_mat(Color(0.8, 0.2, 0.8, 0.22)))
				_trap_preview.set_meta("bord_mat", _make_mat(Color(1.0, 0.5, 1.0, 0.60)))
				_build_tile_disc(_trap_preview, snapped, _trap_preview_radius, 0.0, 0.015)
			_trap_preview.visible = true
		else:
			_trap_preview.visible = false
	else:
		_trap_preview.visible = false

	if _overwatch_selection_active:
		var to_mouse := pos - player_pos
		if to_mouse.length() > 0.2:
			var cone_dir := to_mouse.normalized()
			if cone_dir.distance_to(_overwatch_preview_last_dir) > 0.015:
				_overwatch_preview_last_dir = cone_dir
				_overwatch_preview_disc.set_meta("fill_mat", _make_mat(Color(1.0, 0.85, 0.1, 0.20)))
				_overwatch_preview_disc.set_meta("bord_mat", _make_mat(Color(1.0, 1.0, 0.35, 0.55)))
				_build_cone_disc(_overwatch_preview_disc, player_pos, cone_dir, _overwatch_selection_range, _overwatch_selection_angle)
			_overwatch_preview_disc.visible = true
		else:
			_overwatch_preview_disc.visible = false
	else:
		_overwatch_preview_disc.visible = false

func _show_single_cell(mi: MeshInstance3D, world_pos: Vector2) -> void:
	var cx: float = floor(world_pos.x / 0.08) * 0.08 + 0.04
	var cy: float = floor(world_pos.y / 0.08) * 0.08 + 0.04
	var ty: float = _terrain_height_at(Vector2(cx, cy)) + 0.03
	_build_tile_disc(mi, Vector2(cx, cy), 0.04, 0.0, ty)

# ── Helpers ───────────────────────────────────────────────────────────────────
func movement_distance(a: Vector2, b: Vector2) -> float:
	return a.distance_to(b)

func _in_bounds(pos: Vector2) -> bool:
	return pos.x >= 0.0 and pos.x <= WORLD_W and pos.y >= 0.0 and pos.y <= WORLD_H

# ── Platform helpers ──────────────────────────────────────────────────────────
func _elevation_at(pos: Vector2) -> int:
	for obs in solid_obstacles:
		if obs.get("type", "solid") != "platform": continue
		var p: Vector2 = obs["pos"]
		var h: Vector2 = obs["box"] * 0.5
		if abs(pos.x - p.x) <= h.x and abs(pos.y - p.y) <= h.y:
			return 1
		if _pos_in_ramp(pos, obs):
			return 1
	return 0

func _ray_to_terrain(from: Vector3, dir: Vector3) -> Vector2:
	var best_t := INF

	for obs in solid_obstacles:
		if obs.get("type", "solid") != "platform": continue
		var p: Vector2 = obs["pos"]
		var h: Vector2 = obs["box"] * 0.5

		# Platform top face (y = PLATFORM_HEIGHT plane, clipped to footprint)
		if abs(dir.y) > 0.0001:
			var t_top: float = (PLATFORM_HEIGHT - from.y) / dir.y
			if t_top > 0.001 and t_top < best_t:
				var hit := from + dir * t_top
				if abs(hit.x - p.x) <= h.x and abs(hit.z - p.y) <= h.y:
					best_t = t_top

		# Ramp surfaces
		for ramp in obs.get("ramps", []):
			var t_ramp: float = _ray_to_ramp(from, dir, p, h, ramp)
			if t_ramp > 0.001 and t_ramp < best_t:
				best_t = t_ramp

	# Ground plane y=0
	if abs(dir.y) > 0.0001:
		var t_ground: float = -from.y / dir.y
		if t_ground > 0.001 and t_ground < best_t:
			best_t = t_ground

	if best_t == INF:
		best_t = 1.0
	var hit3 := from + dir * best_t
	return Vector2(clampf(hit3.x, 0.0, WORLD_W), clampf(hit3.z, 0.0, WORLD_H))

func _ray_to_ramp(from: Vector3, dir: Vector3, p: Vector2, h: Vector2, ramp: Dictionary) -> float:
	var w: float = ramp.get("width", 2.0) * 0.5
	var side: String = ramp["side"]
	var denom: float
	var numer: float
	match side:
		"south":
			# Ramp plane: RAMP_DEPTH*y + PLATFORM_HEIGHT*(z - p.y - h.y) = RAMP_DEPTH*PLATFORM_HEIGHT
			denom = RAMP_DEPTH * dir.y + PLATFORM_HEIGHT * dir.z
			numer = PLATFORM_HEIGHT * (RAMP_DEPTH + p.y + h.y) - RAMP_DEPTH * from.y - PLATFORM_HEIGHT * from.z
		"north":
			# Ramp plane: RAMP_DEPTH*y - PLATFORM_HEIGHT*(z - p.y + h.y) = RAMP_DEPTH*PLATFORM_HEIGHT
			denom = RAMP_DEPTH * dir.y - PLATFORM_HEIGHT * dir.z
			numer = PLATFORM_HEIGHT * (RAMP_DEPTH - p.y + h.y) - RAMP_DEPTH * from.y + PLATFORM_HEIGHT * from.z
		"east":
			# Ramp plane: RAMP_DEPTH*y + PLATFORM_HEIGHT*(x - p.x - h.x) = RAMP_DEPTH*PLATFORM_HEIGHT
			denom = RAMP_DEPTH * dir.y + PLATFORM_HEIGHT * dir.x
			numer = PLATFORM_HEIGHT * (RAMP_DEPTH + p.x + h.x) - RAMP_DEPTH * from.y - PLATFORM_HEIGHT * from.x
		"west":
			# Ramp plane: RAMP_DEPTH*y - PLATFORM_HEIGHT*(x - p.x + h.x) = RAMP_DEPTH*PLATFORM_HEIGHT
			denom = RAMP_DEPTH * dir.y - PLATFORM_HEIGHT * dir.x
			numer = PLATFORM_HEIGHT * (RAMP_DEPTH - p.x + h.x) - RAMP_DEPTH * from.y + PLATFORM_HEIGHT * from.x
		_:
			return -1.0
	if abs(denom) < 0.0001:
		return -1.0
	var t := numer / denom
	if t <= 0.001:
		return -1.0
	var hit := from + dir * t
	match side:
		"south": if abs(hit.x - p.x) < w and hit.z >= p.y + h.y and hit.z <= p.y + h.y + RAMP_DEPTH: return t
		"north": if abs(hit.x - p.x) < w and hit.z <= p.y - h.y and hit.z >= p.y - h.y - RAMP_DEPTH: return t
		"east":  if abs(hit.z - p.y) < w and hit.x >= p.x + h.x and hit.x <= p.x + h.x + RAMP_DEPTH: return t
		"west":  if abs(hit.z - p.y) < w and hit.x <= p.x - h.x and hit.x >= p.x - h.x - RAMP_DEPTH: return t
	return -1.0

func _terrain_height_at(pos: Vector2) -> float:
	for obs in solid_obstacles:
		if obs.get("type", "solid") != "platform": continue
		var p: Vector2 = obs["pos"]
		var h: Vector2 = obs["box"] * 0.5
		if abs(pos.x - p.x) <= h.x and abs(pos.y - p.y) <= h.y:
			return PLATFORM_HEIGHT
		for ramp in obs.get("ramps", []):
			var w: float = ramp.get("width", 2.0) * 0.5
			match ramp["side"]:
				"south":
					if abs(pos.x - p.x) < w and pos.y > p.y + h.y and pos.y <= p.y + h.y + RAMP_DEPTH:
						return PLATFORM_HEIGHT * (1.0 - (pos.y - (p.y + h.y)) / RAMP_DEPTH)
				"north":
					if abs(pos.x - p.x) < w and pos.y < p.y - h.y and pos.y >= p.y - h.y - RAMP_DEPTH:
						return PLATFORM_HEIGHT * (1.0 - ((p.y - h.y) - pos.y) / RAMP_DEPTH)
				"east":
					if abs(pos.y - p.y) < w and pos.x > p.x + h.x and pos.x <= p.x + h.x + RAMP_DEPTH:
						return PLATFORM_HEIGHT * (1.0 - (pos.x - (p.x + h.x)) / RAMP_DEPTH)
				"west":
					if abs(pos.y - p.y) < w and pos.x < p.x - h.x and pos.x >= p.x - h.x - RAMP_DEPTH:
						return PLATFORM_HEIGHT * (1.0 - ((p.x - h.x) - pos.x) / RAMP_DEPTH)
	return 0.0

func _pos_in_ramp(pos: Vector2, obs: Dictionary) -> bool:
	# Zona de rampa: FUERA del footprint, extendiéndose RAMP_DEPTH hacia afuera
	var p: Vector2 = obs["pos"]
	var h: Vector2 = obs["box"] * 0.5
	for ramp in obs.get("ramps", []):
		var w: float = ramp.get("width", 2.0) * 0.5
		match ramp["side"]:
			"north": if abs(pos.x - p.x) < w and pos.y < p.y - h.y and pos.y >= p.y - h.y - RAMP_DEPTH: return true
			"south": if abs(pos.x - p.x) < w and pos.y > p.y + h.y and pos.y <= p.y + h.y + RAMP_DEPTH: return true
			"west":  if abs(pos.y - p.y) < w and pos.x < p.x - h.x and pos.x >= p.x - h.x - RAMP_DEPTH: return true
			"east":  if abs(pos.y - p.y) < w and pos.x > p.x + h.x and pos.x <= p.x + h.x + RAMP_DEPTH: return true
	return false

func _pos_in_ramp_exit(pos: Vector2, obs: Dictionary) -> bool:
	# Tira de desmontaje: justo más allá del borde exterior de la rampa, permite bajar al suelo desde elevation=1
	const EXIT := 0.6
	var p: Vector2 = obs["pos"]
	var h: Vector2 = obs["box"] * 0.5
	for ramp in obs.get("ramps", []):
		var w: float = ramp.get("width", 2.0) * 0.5
		match ramp["side"]:
			"north": if abs(pos.x - p.x) < w and pos.y < p.y - h.y - RAMP_DEPTH and pos.y >= p.y - h.y - RAMP_DEPTH - EXIT: return true
			"south": if abs(pos.x - p.x) < w and pos.y > p.y + h.y + RAMP_DEPTH and pos.y <= p.y + h.y + RAMP_DEPTH + EXIT: return true
			"west":  if abs(pos.y - p.y) < w and pos.x < p.x - h.x - RAMP_DEPTH and pos.x >= p.x - h.x - RAMP_DEPTH - EXIT: return true
			"east":  if abs(pos.y - p.y) < w and pos.x > p.x + h.x + RAMP_DEPTH and pos.x <= p.x + h.x + RAMP_DEPTH + EXIT: return true
	return false

# ── Move ──────────────────────────────────────────────────────────────────────
func start_move_selection(move_range: float) -> void:
	selected_move_range = move_range
	_move_reach = _grid_reach(player_pos, move_range, player_elevation,
		_player_shadow_radius, enemy_pos, _enemy_shadow_radius)
	_move_origin = player_pos
	var visible_cells := []
	for cell: Vector2i in _move_reach:
		if _in_move_circle(cell, _move_origin, move_range):
			visible_cells.append(cell)
	_build_cells_on_terrain(_move_disc, visible_cells)
	_show_footprint(_player_circle, player_pos, _player_shadow_radius)


func _tile_in_obstacle(pos: Vector2, elevation: int = 0) -> bool:
	for obs in solid_obstacles:
		var obs_type: String = obs.get("type", "solid")
		if obs_type == "bridge": continue
		if obs_type == "platform":
			if elevation > 0: continue  # elevado: footprint es transitable
			var p: Vector2 = obs["pos"]
			var h: Vector2 = obs["box"] * 0.5
			if abs(pos.x - p.x) < h.x and abs(pos.y - p.y) < h.y:
				return true  # footprint bloqueado al nivel del suelo
			continue  # fuera del footprint (incl. rampa exterior) → libre
		if obs.has("box"):
			var half: Vector2 = obs["box"] * 0.5
			var p: Vector2    = obs["pos"]
			if abs(pos.x - p.x) < half.x and abs(pos.y - p.y) < half.y:
				return true
		else:
			if pos.distance_to(obs["pos"]) < obs["radius"]:
				return true
	return false

func _apply_two_surface_mesh(mi: MeshInstance3D,
		fv: PackedVector3Array, fi: PackedInt32Array,
		bv: PackedVector3Array, bi: PackedInt32Array) -> void:
	if fv.is_empty():
		# Una malla sin vértices hace fallar add_surface_from_arrays.
		mi.visible = false
		return
	var mesh := ArrayMesh.new()
	var fa := []; fa.resize(Mesh.ARRAY_MAX)
	fa[Mesh.ARRAY_VERTEX] = fv; fa[Mesh.ARRAY_INDEX] = fi
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, fa)
	var ba := []; ba.resize(Mesh.ARRAY_MAX)
	ba[Mesh.ARRAY_VERTEX] = bv; ba[Mesh.ARRAY_INDEX] = bi
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ba)
	mi.mesh = mesh
	mi.set_surface_override_material(0, mi.get_meta("fill_mat") if mi.has_meta("fill_mat") else null)
	mi.set_surface_override_material(1, mi.get_meta("bord_mat") if mi.has_meta("bord_mat") else null)
	mi.visible = fv.size() > 0

func _build_cells_mesh(mi: MeshInstance3D, cells: Array[Vector2i], y: float) -> void:
	const CELL   := 0.08
	const BORDER := 0.010
	var half     := CELL * 0.5
	var fill_v   := PackedVector3Array()
	var fill_i   := PackedInt32Array()
	var bord_v   := PackedVector3Array()
	var bord_i   := PackedInt32Array()
	for cell in cells:
		var cx: float = (cell.x + 0.5) * CELL
		var cy: float = (cell.y + 0.5) * CELL
		var fi := fill_v.size()
		fill_v.append(Vector3(cx-half+BORDER, y,        cy-half+BORDER))
		fill_v.append(Vector3(cx+half-BORDER, y,        cy-half+BORDER))
		fill_v.append(Vector3(cx+half-BORDER, y,        cy+half-BORDER))
		fill_v.append(Vector3(cx-half+BORDER, y,        cy+half-BORDER))
		fill_i.append_array([fi, fi+1, fi+2, fi, fi+2, fi+3])
		var strips := [
			[cx-half, cy-half,        cx+half,        cy-half+BORDER],
			[cx-half, cy+half-BORDER, cx+half,        cy+half],
			[cx-half, cy-half+BORDER, cx-half+BORDER, cy+half-BORDER],
			[cx+half-BORDER, cy-half+BORDER, cx+half, cy+half-BORDER],
		]
		for s in strips:
			var x0: float = s[0]; var z0: float = s[1]
			var x1: float = s[2]; var z1: float = s[3]
			var bi := bord_v.size()
			bord_v.append(Vector3(x0, y+0.001, z0)); bord_v.append(Vector3(x1, y+0.001, z0))
			bord_v.append(Vector3(x1, y+0.001, z1)); bord_v.append(Vector3(x0, y+0.001, z1))
			bord_i.append_array([bi, bi+1, bi+2, bi, bi+2, bi+3])
	var mesh := ArrayMesh.new()
	var fa := []; fa.resize(Mesh.ARRAY_MAX)
	fa[Mesh.ARRAY_VERTEX] = fill_v; fa[Mesh.ARRAY_INDEX] = fill_i
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, fa)
	var ba := []; ba.resize(Mesh.ARRAY_MAX)
	ba[Mesh.ARRAY_VERTEX] = bord_v; ba[Mesh.ARRAY_INDEX] = bord_i
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ba)
	mi.mesh = mesh
	mi.set_surface_override_material(0, mi.get_meta("fill_mat") if mi.has_meta("fill_mat") else null)
	mi.set_surface_override_material(1, mi.get_meta("bord_mat") if mi.has_meta("bord_mat") else null)
	mi.visible = fill_v.size() > 0

func clear_move_selection() -> void:
	selected_move_range   = 0.0
	_move_disc.visible       = false
	_player_circle.visible   = false

func show_move_preview(pos: Vector2) -> void:
	_show_disc(_dest_marker, pos, 0.5)

func clear_move_preview() -> void:
	_dest_marker.visible = false

func show_path_preview(_from: Vector2, _to: Vector2) -> void:
	# Usa _last_path, que arma plan_player_move()
	if _last_path.size() < 2:
		_path_highlight.visible = false
		return
	const CELL   := 0.08
	const BORDER := 0.010
	var half     := CELL * 0.5
	var fill_v   := PackedVector3Array()
	var fill_i   := PackedInt32Array()
	var bord_v   := PackedVector3Array()
	var bord_i   := PackedInt32Array()
	var seen     := {}

	# Walk each segment of the A* path and collect visual cells
	for seg in range(_last_path.size() - 1):
		var p0: Vector2 = _last_path[seg]
		var p1: Vector2 = _last_path[seg + 1]
		var seg_dist := p0.distance_to(p1)
		var steps    := maxi(1, int(seg_dist / (CELL * 0.4)))
		for i in range(steps + 1):
			var p  := p0.lerp(p1, float(i) / float(steps))
			var gx := int(floor(p.x / CELL))
			var gy := int(floor(p.y / CELL))
			var key := Vector2i(gx, gy)
			if key in seen: continue
			seen[key] = true
			var cx: float = gx * CELL + CELL * 0.5
			var cy: float = gy * CELL + CELL * 0.5
			var ty: float = _terrain_height_at(Vector2(cx, cy)) + 0.025
			var fi := fill_v.size()
			fill_v.append(Vector3(cx-half+BORDER, ty, cy-half+BORDER))
			fill_v.append(Vector3(cx+half-BORDER, ty, cy-half+BORDER))
			fill_v.append(Vector3(cx+half-BORDER, ty, cy+half-BORDER))
			fill_v.append(Vector3(cx-half+BORDER, ty, cy+half-BORDER))
			fill_i.append_array([fi, fi+1, fi+2, fi, fi+2, fi+3])
			var ty1: float = ty + 0.001
			var strips := [
				[cx-half, cy-half,        cx+half,        cy-half+BORDER],
				[cx-half, cy+half-BORDER, cx+half,        cy+half],
				[cx-half, cy-half+BORDER, cx-half+BORDER, cy+half-BORDER],
				[cx+half-BORDER, cy-half+BORDER, cx+half, cy+half-BORDER],
			]
			for s in strips:
				var x0: float = s[0]; var z0: float = s[1]
				var x1: float = s[2]; var z1: float = s[3]
				var bi := bord_v.size()
				bord_v.append(Vector3(x0, ty1, z0)); bord_v.append(Vector3(x1, ty1, z0))
				bord_v.append(Vector3(x1, ty1, z1)); bord_v.append(Vector3(x0, ty1, z1))
				bord_i.append_array([bi, bi+1, bi+2, bi, bi+2, bi+3])

	var mesh := ArrayMesh.new()
	var fa := []; fa.resize(Mesh.ARRAY_MAX)
	fa[Mesh.ARRAY_VERTEX] = fill_v; fa[Mesh.ARRAY_INDEX] = fill_i
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, fa)
	var ba := []; ba.resize(Mesh.ARRAY_MAX)
	ba[Mesh.ARRAY_VERTEX] = bord_v; ba[Mesh.ARRAY_INDEX] = bord_i
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ba)
	_path_highlight.mesh = mesh
	_path_highlight.set_surface_override_material(0, _path_highlight.get_meta("fill_mat") if _path_highlight.has_meta("fill_mat") else null)
	_path_highlight.set_surface_override_material(1, _path_highlight.get_meta("bord_mat") if _path_highlight.has_meta("bord_mat") else null)
	_path_highlight.visible = fill_v.size() > 0

func clear_path_preview() -> void:
	_path_highlight.visible = false

func try_move_player_to(pos: Vector2, _range: float) -> bool:
	var goal := CombatGrid.to_cell(pos)
	if not _in_move_circle(goal, _move_origin, selected_move_range):
		return false
	var path := CombatGrid.path_to(_move_reach, goal)
	if path.size() < 2:
		return false
	var from_elevation := player_elevation
	player_pos       = CombatGrid.to_world(goal)
	player_elevation = _elevation_at(player_pos)
	# El personaje recorre el camino esquina por esquina.
	_player_waypoints.clear()
	for cell in CombatGrid.corners(path).slice(1):
		var w := CombatGrid.to_world(cell)
		_player_waypoints.append(Vector3(w.x, _player_y_at(w, maxi(from_elevation, _elevation_at(w))), w.y))
	_last_path       = []
	_last_path_cost  = 0.0
	clear_move_selection()
	_update_actor_positions()
	if not _player_waypoints.is_empty():
		_player_waypoints[-1] = _player_target
	return true

func get_path_cost(_pos: Vector2) -> float:
	return _last_path_cost

## Prepara el movimiento del jugador hacia pos dentro de la selección actual.
## Devuelve "" si se puede (y deja el camino listo para show_path_preview),
## o el motivo: "range", "blocked" o "no_path".
func plan_player_move(pos: Vector2) -> String:
	var goal := CombatGrid.to_cell(pos)
	if not _move_reach.has(goal) or not _in_move_circle(goal, _move_origin, selected_move_range):
		_last_path = []
		_last_path_cost = INF
		if not _in_move_circle(goal, _move_origin, selected_move_range):
			return "range"
		if not _grid_passable(goal, player_elevation, _player_shadow_radius, enemy_pos, _enemy_shadow_radius):
			return "blocked"
		return "no_path"
	var path := CombatGrid.path_to(_move_reach, goal)
	_last_path.clear()
	for cell in CombatGrid.corners(path):
		_last_path.append(CombatGrid.to_world(cell))
	# El camino en 8 direcciones sobreestima la línea recta hasta un 8 %: se
	# escala para que un movimiento directo cueste su distancia real y un
	# rodeo cueste proporcionalmente más.
	var start := CombatGrid.to_cell(_move_origin)
	var direct := CombatGrid.octile(goal - start)
	var scale := 1.0
	if direct > 0.0:
		scale = (CombatGrid.to_world(goal).distance_to(CombatGrid.to_world(start)) / CombatGrid.CELL) / direct
	_last_path_cost = float(_move_reach[goal]["cost"]) * scale * CombatGrid.CELL
	return ""

# ── Grilla de movimiento ──────────────────────────────────────────────────────

## Casillas alcanzables (8 direcciones) desde from_pos para un personaje de huella
## `radius`, sin pisar obstáculos ni la huella del otro personaje.
func _grid_reach(from_pos: Vector2, move_range: float, elevation: int, radius: float,
		other_pos: Vector2, other_radius: float) -> Dictionary:
	var start := CombatGrid.to_cell(from_pos)
	# Si ya arranca encimado (tras un salto o un empuje), se le permite salir:
	# basta con que el centro esté libre y no se acerque más al otro personaje.
	var escape_sep := -1.0
	if not _grid_passable(start, elevation, radius, other_pos, other_radius):
		escape_sep = minf(radius + other_radius, CombatGrid.to_world(start).distance_to(other_pos))
	return CombatGrid.reachable(start, CombatGrid.steps_for(move_range * PATH_SLACK),
		func(c: Vector2i) -> bool: return _grid_passable(c, elevation, radius, other_pos, other_radius, escape_sep))

## El alcance de movimiento se mide en línea recta: un círculo alrededor de origin.
func _in_move_circle(cell: Vector2i, origin: Vector2, move_range: float) -> bool:
	return CombatGrid.to_world(cell).distance_to(origin) <= move_range + CombatGrid.CELL * 0.5

## Una casilla es válida si la huella (círculo de `radius`) centrada ahí no toca
## obstáculos ni la huella del otro. escape_sep >= 0 activa el modo escape.
func _grid_passable(cell: Vector2i, elevation: int, radius: float, other_pos: Vector2,
		other_radius: float, escape_sep := -1.0) -> bool:
	var w := CombatGrid.to_world(cell)
	if not _in_bounds(w):
		return false
	var escape := escape_sep >= 0.0
	if _cell_blocked(cell, w, elevation, 0.0 if escape else radius):
		return false
	var min_sep := escape_sep if escape else radius + other_radius
	return w.distance_to(other_pos) >= min_sep - 0.0001

## Llena de a poco los cachés de altura y de obstáculos (con las huellas de
## ambos personajes) para que el primer movimiento no tenga un tirón.
func _warm_grid_caches() -> void:
	if _warm_next < 0:
		return
	var cols := CombatGrid.steps_for(WORLD_W) + 1
	var total := cols * (CombatGrid.steps_for(WORLD_H) + 1)
	var end := mini(_warm_next + WARM_CELLS_PER_FRAME, total)
	for i in range(_warm_next, end):
		var cell := Vector2i(i % cols, i / cols)
		var w := CombatGrid.to_world(cell)
		_cell_height(cell, w)
		_cell_blocked(cell, w, 0, _player_shadow_radius)
		_cell_blocked(cell, w, 0, _enemy_shadow_radius)
	_warm_next = end if end < total else -1

func _cell_height(cell: Vector2i, w: Vector2) -> float:
	var cols := CombatGrid.steps_for(WORLD_W) + 1
	var rows := CombatGrid.steps_for(WORLD_H) + 1
	if _height_cache.is_empty():
		_height_cache.resize(cols * rows)
		_height_cache.fill(NAN)
	if cell.x < 0 or cell.y < 0 or cell.x >= cols or cell.y >= rows:
		return _terrain_height_at(w)
	var i := cell.y * cols + cell.x
	if is_nan(_height_cache[i]):
		_height_cache[i] = _terrain_height_at(w)
	return _height_cache[i]

func _cell_blocked(cell: Vector2i, w: Vector2, elevation: int, margin: float) -> bool:
	var by_margin: Dictionary = _blocked_cache.get_or_add(margin, {})
	var key := Vector3i(cell.x, cell.y, elevation)
	if not by_margin.has(key):
		by_margin[key] = _pos_blocked(w, elevation, margin)
	return by_margin[key]

func _player_y_at(pos: Vector2, elevation: int) -> float:
	if elevation > 0:
		for obs in solid_obstacles:
			if obs.get("type", "solid") != "platform": continue
			var p: Vector2 = obs["pos"]
			var hh: Vector2 = obs["box"] * 0.5
			if abs(pos.x - p.x) <= hh.x and abs(pos.y - p.y) <= hh.y:
				return PLATFORM_HEIGHT
	return 0.0

## Dibuja las casillas dadas apoyadas sobre el terreno (cada una a su altura).
## Arreglos pre-dimensionados: con alcances grandes son decenas de miles de casillas.
func _build_cells_on_terrain(mi: MeshInstance3D, cells: Array) -> void:
	const BORDER := 0.010
	var half := CombatGrid.CELL * 0.5
	var n := cells.size()
	var fv := PackedVector3Array(); fv.resize(n * 4)
	var fi := PackedInt32Array(); fi.resize(n * 6)
	var bv := PackedVector3Array(); bv.resize(n * 16)
	var bi := PackedInt32Array(); bi.resize(n * 24)
	var k := 0
	for cell: Vector2i in cells:
		var c := CombatGrid.to_world(cell)
		var x0 := c.x - half
		var x1 := c.x + half
		var z0 := c.y - half
		var z1 := c.y + half
		var y: float = _cell_height(cell, c) + 0.02
		var yb := y + 0.001
		var v := k * 4
		fv[v]     = Vector3(x0 + BORDER, y, z0 + BORDER)
		fv[v + 1] = Vector3(x1 - BORDER, y, z0 + BORDER)
		fv[v + 2] = Vector3(x1 - BORDER, y, z1 - BORDER)
		fv[v + 3] = Vector3(x0 + BORDER, y, z1 - BORDER)
		var t := k * 6
		fi[t] = v; fi[t + 1] = v + 1; fi[t + 2] = v + 2
		fi[t + 3] = v; fi[t + 4] = v + 2; fi[t + 5] = v + 3
		# Cuatro tiras de borde: arriba, abajo, izquierda, derecha.
		var b := k * 16
		_quad(bv, bi, b,      k * 24,      x0, z0, x1, z0 + BORDER, yb)
		_quad(bv, bi, b + 4,  k * 24 + 6,  x0, z1 - BORDER, x1, z1, yb)
		_quad(bv, bi, b + 8,  k * 24 + 12, x0, z0 + BORDER, x0 + BORDER, z1 - BORDER, yb)
		_quad(bv, bi, b + 12, k * 24 + 18, x1 - BORDER, z0 + BORDER, x1, z1 - BORDER, yb)
		k += 1
	_apply_two_surface_mesh(mi, fv, fi, bv, bi)

static func _quad(v: PackedVector3Array, idx: PackedInt32Array, vi: int, ii: int,
		x0: float, z0: float, x1: float, z1: float, y: float) -> void:
	v[vi]     = Vector3(x0, y, z0)
	v[vi + 1] = Vector3(x1, y, z0)
	v[vi + 2] = Vector3(x1, y, z1)
	v[vi + 3] = Vector3(x0, y, z1)
	idx[ii] = vi; idx[ii + 1] = vi + 1; idx[ii + 2] = vi + 2
	idx[ii + 3] = vi; idx[ii + 4] = vi + 2; idx[ii + 5] = vi + 3

## true si un círculo de radio `margin` en wp choca con obstáculos al nivel `elevation`.
func _pos_blocked(wp: Vector2, elevation: int = 0, margin: float = PATH_CELL * 0.5) -> bool:
	# Elevado: solo puede moverse en el footprint de la plataforma, la rampa exterior o la tira de desmontaje
	if elevation > 0:
		for obs in solid_obstacles:
			if obs.get("type", "solid") != "platform": continue
			var p: Vector2 = obs["pos"]
			var h: Vector2 = obs["box"] * 0.5
			var in_footprint: bool = abs(wp.x - p.x) <= h.x + PATH_CELL * 0.5 and abs(wp.y - p.y) <= h.y + PATH_CELL * 0.5
			if in_footprint or _pos_in_ramp(wp, obs) or _pos_in_ramp_exit(wp, obs):
				return false
		return true  # fuera de toda plataforma → bloqueado

	for obs in solid_obstacles:
		var obs_type: String = obs.get("type", "solid")
		if obs_type == "bridge": continue
		if obs_type == "platform":
			var p: Vector2 = obs["pos"]
			var h: Vector2 = obs["box"] * 0.5 + Vector2(margin, margin)
			if abs(wp.x - p.x) < h.x and abs(wp.y - p.y) < h.y:
				return true  # footprint bloqueado al nivel del suelo
			continue  # fuera del footprint (incl. rampa exterior) → no bloqueado
		if obs.has("box"):
			var half: Vector2 = obs["box"] * 0.5 + Vector2(margin, margin)
			var p: Vector2    = obs["pos"]
			if abs(wp.x - p.x) < half.x and abs(wp.y - p.y) < half.y:
				return true
		else:
			if wp.distance_to(obs["pos"]) < obs["radius"] + margin:
				return true
	return false

# ── Attack ────────────────────────────────────────────────────────────────────
func start_attack_selection(attack_range: float) -> void:
	selected_attack_range = attack_range
	# El alcance se cuenta desde el borde de la huella del jugador.
	_show_disc(_attack_disc, player_pos, attack_range + _player_shadow_radius)
	_show_footprint(_enemy_hover, enemy_pos, _enemy_shadow_radius, HOVER_Y)
	_enemy_hover.visible = false

func clear_attack_selection() -> void:
	selected_attack_range = 0.0
	_attack_disc.visible  = false
	_enemy_hover.visible  = false

## Distancia entre los bordes de las huellas del jugador y del enemigo.
func actors_gap() -> float:
	return movement_distance(player_pos, enemy_pos) - _player_shadow_radius - _enemy_shadow_radius

## El alcance se mide entre los bordes de las huellas: con huellas circulares
## los centros nunca quedan a menos de la suma de los radios. Media casilla de
## tolerancia porque las posiciones caen en centros de casilla.
func is_enemy_in_attack_range(attack_range: float) -> bool:
	return actors_gap() <= attack_range + CombatGrid.CELL * 0.5 \
		and has_line_of_sight(player_pos, enemy_pos)

func is_enemy_in_melee_range() -> bool:
	return movement_distance(player_pos, enemy_pos) <= 1.5

func is_player_in_melee_range() -> bool:
	return movement_distance(enemy_pos, player_pos) <= 1.5

# ── LOS ───────────────────────────────────────────────────────────────────────
# Núcleo compartido. block_rocks / block_bridges controlan qué tipos tapan el rayo.
# from_elev / to_elev se usan para la plataforma: si cualquiera está elevado, no bloquea.
func _los_clear(from: Vector2, to: Vector2,
		block_rocks: bool, block_bridges: bool,
		from_elev: int, to_elev: int) -> bool:
	for obs in solid_obstacles:
		var obs_type: String = obs.get("type", "solid")
		if obs_type == "rock"   and not block_rocks:   continue
		if obs_type == "bridge" and not block_bridges: continue
		if obs_type == "platform":
			if from_elev > 0 or to_elev > 0: continue
			if _segment_hits_box(from, to, obs["pos"], obs["box"] * 0.5):
				return false
			continue
		if obs.has("box"):
			if _segment_hits_box(from, to, obs["pos"], obs["box"] * 0.5):
				return false
		else:
			if _segment_hits_circle(from, to, obs["pos"], obs["radius"]):
				return false
	return true

# LOS para ataques de rango: rocas transparentes, puentes opacos.
func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	return _los_clear(from, to, false, true, _elevation_at(from), _elevation_at(to))

# LOS para movimiento: rocas bloquean, puentes son transitables por debajo.
func _segment_hits_box(a: Vector2, b: Vector2, center: Vector2, half: Vector2) -> bool:
	var d := b - a
	var tmin := 0.0
	var tmax := 1.0
	for axis in range(2):
		var da: float = d[axis]
		var lo: float = center[axis] - half[axis] - a[axis]
		var hi: float = center[axis] + half[axis] - a[axis]
		if abs(da) < 0.0001:
			if lo > 0.0 or hi < 0.0: return false
		else:
			var t0 := lo / da
			var t1 := hi / da
			if t0 > t1:
				var tmp := t0; t0 = t1; t1 = tmp
			tmin = maxf(tmin, t0)
			tmax = minf(tmax, t1)
			if tmin > tmax: return false
	return true

func _segment_hits_circle(a: Vector2, b: Vector2, c: Vector2, r: float) -> bool:
	var d  := b - a
	var f  := a - c
	var bv := 2.0 * f.dot(d)
	var cv := f.dot(f) - r * r
	var disc := bv * bv - 4.0 * d.dot(d) * cv
	if disc < 0.0: return false
	var sq    := sqrt(disc)
	var denom := 2.0 * d.dot(d)
	var t1    := (-bv - sq) / denom
	var t2    := (-bv + sq) / denom
	return (t1 >= 0.0 and t1 <= 1.0) or (t2 >= 0.0 and t2 <= 1.0)

# ── Target highlights ─────────────────────────────────────────────────────────
func start_enemy_highlight() -> void:
	_show_footprint(_enemy_highlight, enemy_pos, _enemy_shadow_radius)
	_show_footprint(_enemy_hover, enemy_pos, _enemy_shadow_radius, HOVER_Y)
	_enemy_hover.visible = false

func clear_enemy_highlight() -> void:
	_enemy_highlight.visible = false
	_enemy_hover.visible     = false

func start_self_highlight() -> void:
	_show_footprint(_self_highlight, player_pos, _player_shadow_radius)
	_show_footprint(_self_hover, player_pos, _player_shadow_radius, HOVER_Y)
	_self_hover.visible = false

func clear_self_highlight() -> void:
	_self_highlight.visible = false
	_self_hover.visible     = false

## Un clic "toca" a un personaje si cae sobre su huella o cerca (CLICK_MARGIN).
func is_click_on_enemy(pos: Vector2) -> bool:
	return pos.distance_to(enemy_pos) <= _enemy_shadow_radius + CLICK_MARGIN

func is_click_on_player(pos: Vector2) -> bool:
	return pos.distance_to(player_pos) <= _player_shadow_radius + CLICK_MARGIN

# ── Enemy ─────────────────────────────────────────────────────────────────────
func set_enemy_hp(hp: int) -> void:
	enemy_hp = hp

func can_place_enemy(pos: Vector2) -> bool:
	return _in_bounds(pos)

## Mueve al enemigo hasta la casilla alcanzable más cercana a target.
func move_enemy_toward(target: Vector2, move_range: float) -> bool:
	if enemy_pos.distance_to(target) < 0.01: return false
	var reach := _grid_reach(enemy_pos, move_range, enemy_elevation,
		_enemy_shadow_radius, player_pos, _player_shadow_radius)
	var start := CombatGrid.to_cell(enemy_pos)
	var best := start
	var best_d := enemy_pos.distance_to(target)
	var best_cost := 0.0
	for cell: Vector2i in reach:
		if not _in_move_circle(cell, enemy_pos, move_range):
			continue
		var d := CombatGrid.to_world(cell).distance_to(target)
		var cost: float = reach[cell]["cost"]
		if d < best_d - 0.0001 or (absf(d - best_d) <= 0.0001 and cost < best_cost):
			best = cell
			best_d = d
			best_cost = cost
	if best == start:
		return false
	var path := CombatGrid.path_to(reach, best)
	_enemy_waypoints.clear()
	for cell in CombatGrid.corners(path).slice(1):
		var w := CombatGrid.to_world(cell)
		_enemy_waypoints.append(Vector3(w.x, float(_elevation_at(w)) * PLATFORM_HEIGHT, w.y))
	enemy_pos       = CombatGrid.to_world(best)
	enemy_elevation = _elevation_at(enemy_pos)
	_update_actor_positions()
	return true

# ── Traps ─────────────────────────────────────────────────────────────────────
func start_trap_placement(trap_range: float, trap_radius: float = 1.0) -> void:
	selected_trap_range  = trap_range
	_trap_preview_radius = trap_radius
	_trap_preview_last_pos = Vector2(-999.0, -999.0)
	_trap_preview.visible  = false
	_show_disc_with_los(_trap_disc, player_pos, trap_range, player_elevation)

func _show_disc_with_los(mi: MeshInstance3D, origin: Vector2, radius: float, elevation: int = 0, block_rocks: bool = false, block_bridges: bool = true) -> void:
	const VCELL  := 0.08
	const BORDER := 0.010
	var half     := VCELL * 0.5
	var fv := PackedVector3Array(); var fi := PackedInt32Array()
	var bv := PackedVector3Array(); var bi := PackedInt32Array()
	var vgx0 := int(floor((origin.x - radius) / VCELL))
	var vgx1 := int(ceil( (origin.x + radius) / VCELL))
	var vgy0 := int(floor((origin.y - radius) / VCELL))
	var vgy1 := int(ceil( (origin.y + radius) / VCELL))
	for gx in range(vgx0, vgx1 + 1):
		for gy in range(vgy0, vgy1 + 1):
			var cx: float = (gx + 0.5) * VCELL
			var cy: float = (gy + 0.5) * VCELL
			var cell_pos := Vector2(cx, cy)
			var px := clampf(origin.x, cx - half, cx + half)
			var py := clampf(origin.y, cy - half, cy + half)
			if Vector2(px, py).distance_to(origin) > radius: continue
			if _tile_in_obstacle(cell_pos, elevation):        continue
			if not _los_clear(origin, cell_pos, block_rocks, block_bridges, elevation, elevation): continue
			var y: float = _terrain_height_at(cell_pos) + 0.02
			var f := fv.size()
			fv.append(Vector3(cx-half+BORDER, y, cy-half+BORDER))
			fv.append(Vector3(cx+half-BORDER, y, cy-half+BORDER))
			fv.append(Vector3(cx+half-BORDER, y, cy+half-BORDER))
			fv.append(Vector3(cx-half+BORDER, y, cy+half-BORDER))
			fi.append_array([f, f+1, f+2, f, f+2, f+3])
			var strips := [
				[cx-half, cy-half,        cx+half,        cy-half+BORDER],
				[cx-half, cy+half-BORDER, cx+half,        cy+half],
				[cx-half, cy-half+BORDER, cx-half+BORDER, cy+half-BORDER],
				[cx+half-BORDER, cy-half+BORDER, cx+half, cy+half-BORDER],
			]
			for s in strips:
				var x0: float = s[0]; var z0: float = s[1]
				var x1: float = s[2]; var z1: float = s[3]
				var b := bv.size()
				bv.append(Vector3(x0, y+0.001, z0)); bv.append(Vector3(x1, y+0.001, z0))
				bv.append(Vector3(x1, y+0.001, z1)); bv.append(Vector3(x0, y+0.001, z1))
				bi.append_array([b, b+1, b+2, b, b+2, b+3])
	_apply_two_surface_mesh(mi, fv, fi, bv, bi)

func clear_trap_placement() -> void:
	selected_trap_range    = 0.0
	_trap_disc.visible     = false
	_trap_preview.visible  = false
	_trap_preview_last_pos = Vector2(-999.0, -999.0)

func place_trap(pos: Vector2, radius: float, damage: int, card_name: String) -> void:
	trap_zones.append({"pos": pos, "radius": float(radius), "damage": damage, "name": card_name})
	_add_trap_visual(pos, float(radius))

func _add_trap_visual(pos: Vector2, radius: float) -> void:
	var mi := MeshInstance3D.new()
	mi.set_meta("fill_mat", _make_mat(Color(0.8, 0.2, 0.8, 0.25)))
	mi.set_meta("bord_mat", _make_mat(Color(1.0, 0.5, 1.0, 0.70)))
	add_child(mi)
	_build_tile_disc(mi, pos, radius, 0.0, 0.015)
	_trap_visuals.append(mi)

func check_and_trigger_traps(unit_pos: Vector2) -> int:
	var total := 0
	var triggered: Array = []
	for trap in trap_zones:
		if movement_distance(trap["pos"], unit_pos) <= trap["radius"]:
			total += trap["damage"]
			triggered.append(trap)
	for t in triggered:
		var idx := trap_zones.find(t)
		if idx >= 0 and idx < _trap_visuals.size():
			_trap_visuals[idx].queue_free()
			_trap_visuals.remove_at(idx)
		trap_zones.erase(t)
	return total

func check_and_trigger_traps_along_path(_from: Vector2, to: Vector2) -> int:
	return check_and_trigger_traps(to)

# ── Grenade ───────────────────────────────────────────────────────────────────
func calculate_grenade_landing(from: Vector2, target: Vector2, bounce: float) -> Vector2:
	var landing: Vector2
	if bounce == 0.0:
		landing = target
	else:
		var dir := (target - from).normalized()
		landing  = target + dir.rotated(randf_range(-PI / 5.0, PI / 5.0)) * bounce * 10.0
		landing  = Vector2(clampf(landing.x, 0.0, WORLD_W), clampf(landing.y, 0.0, WORLD_H))
	return _clip_path_at_obstacle(from, landing)

# Returns the point where the segment from→to first hits an obstacle, or to if clear.
func _clip_path_at_obstacle(from: Vector2, to: Vector2) -> Vector2:
	var closest_t := 1.0
	for obs in solid_obstacles:
		if obs.get("type", "solid") == "rock": continue  # granadas vuelan por encima
		var t: float
		if obs.has("box"):
			t = _segment_hit_t_box(from, to, obs["pos"], obs["box"] * 0.5)
		else:
			t = _segment_hit_t_circle(from, to, obs["pos"], obs["radius"])
		if t >= 0.0 and t < closest_t:
			closest_t = t
	if closest_t < 1.0:
		return from + (to - from) * maxf(0.0, closest_t - 0.05)
	return to

func _segment_hit_t_circle(a: Vector2, b: Vector2, c: Vector2, r: float) -> float:
	var d  := b - a
	var f  := a - c
	var bv := 2.0 * f.dot(d)
	var cv := f.dot(f) - r * r
	var disc := bv * bv - 4.0 * d.dot(d) * cv
	if disc < 0.0: return -1.0
	var sq    := sqrt(disc)
	var denom := 2.0 * d.dot(d)
	var t1    := (-bv - sq) / denom
	var t2    := (-bv + sq) / denom
	if t1 >= 0.0 and t1 <= 1.0: return t1
	if t2 >= 0.0 and t2 <= 1.0: return t2
	return -1.0

func _segment_hit_t_box(a: Vector2, b: Vector2, center: Vector2, half: Vector2) -> float:
	var d    := b - a
	var tmin := 0.0
	var tmax := 1.0
	for axis in range(2):
		var da: float = d[axis]
		var lo: float = center[axis] - half[axis] - a[axis]
		var hi: float = center[axis] + half[axis] - a[axis]
		if abs(da) < 0.0001:
			if lo > 0.0 or hi < 0.0: return -1.0
		else:
			var t0 := lo / da
			var t1 := hi / da
			if t0 > t1:
				var tmp := t0; t0 = t1; t1 = tmp
			tmin = maxf(tmin, t0)
			tmax = minf(tmax, t1)
			if tmin > tmax: return -1.0
	return tmin

func show_grenade_preview(landing: Vector2, aoe_radius: float) -> void:
	grenade_landing    = landing
	grenade_aoe_radius = float(aoe_radius)
	_show_disc(_grenade_disc, landing, grenade_aoe_radius)

func clear_grenade_preview() -> void:
	grenade_landing       = Vector2(-1.0, -1.0)
	grenade_aoe_radius    = 0.0
	_grenade_disc.visible = false

func is_enemy_in_explosion(center: Vector2, radius: float) -> bool:
	return movement_distance(center, enemy_pos) <= float(radius)

# ── Rock Jump ─────────────────────────────────────────────────────────────────
func get_rocks_in_range(origin: Vector2, range: float) -> Array[Dictionary]:
	var rocks: Array[Dictionary] = []
	for obs in solid_obstacles:
		if obs.get("type", "solid") != "rock" and not is_module(obs):
			continue
		if origin.distance_to(obs["pos"]) <= range:
			rocks.append(obs)
	return rocks

func start_rock_jump_selection(jump_range: float) -> void:
	_show_disc(_jump_disc, player_pos, jump_range)
	_jump_rocks_in_range = get_rocks_in_range(player_pos, jump_range)
	for obs in _jump_rocks_in_range:
		var mi := _make_disc(Color(0.2, 1.0, 0.5, 0.75))
		_build_tile_disc(mi, obs["pos"], obs.get("radius", 0.5) * 1.8, 0.0, HIGHLIGHT_Y)
		_jump_rock_markers.append(mi)

func get_rock_near(pos: Vector2) -> Dictionary:
	for obs in _jump_rocks_in_range:
		var r: float = obs.get("radius", 0.5)
		if pos.distance_to(obs["pos"]) <= r + 1.5:
			return obs
	return {}

func start_jump_landing_selection(rock_pos: Vector2, landing_range: float) -> void:
	_jump_disc.visible = false
	for marker in _jump_rock_markers:
		marker.queue_free()
	_jump_rock_markers.clear()
	_show_disc(_jump_landing_disc, rock_pos, landing_range)
	_build_tile_disc(_jump_selected_marker, rock_pos, 0.7, 0.0, HOVER_Y)

func clear_rock_jump_selection() -> void:
	_jump_disc.visible            = false
	_jump_landing_disc.visible    = false
	_jump_selected_marker.visible = false
	for marker in _jump_rock_markers:
		marker.queue_free()
	_jump_rock_markers.clear()
	_jump_rocks_in_range.clear()

func is_enemy_near_pos(pos: Vector2, radius: float) -> bool:
	return pos.distance_to(enemy_pos) <= radius

# ── Push ──────────────────────────────────────────────────────────────────────
func start_push_enemy_selection(grab_range: float) -> void:
	# Como en el ataque: el alcance se cuenta desde el borde de la huella.
	_show_disc(_attack_disc, player_pos, grab_range + _player_shadow_radius)
	start_enemy_highlight()

func start_push_cone(push_range: float) -> void:
	_push_enemy_disc.visible = false
	var dir: Vector2 = (enemy_pos - player_pos).normalized()
	_build_cone_disc(_push_disc, enemy_pos, dir, push_range, 55.0)

func clear_push_selection() -> void:
	_push_disc.visible       = false
	_push_enemy_disc.visible = false
	_attack_disc.visible     = false
	clear_enemy_highlight()

func is_pos_in_push_cone(pos: Vector2, push_range: float) -> bool:
	var to_pos: Vector2 = pos - enemy_pos
	if to_pos.length() < 0.001:
		return false
	if to_pos.length() > push_range:
		return false
	var dir: Vector2 = (enemy_pos - player_pos).normalized()
	return absf(dir.angle_to(to_pos.normalized())) <= deg_to_rad(55.0)

func _build_cone_disc(mi: MeshInstance3D, origin: Vector2, direction: Vector2, max_range: float, half_angle_deg: float) -> void:
	const CELL   := 0.08
	const BORDER := 0.010
	const Y      := 0.02
	var half      := CELL * 0.5
	var half_rad  := deg_to_rad(half_angle_deg)
	var dir_norm  := direction.normalized()

	var fill_v := PackedVector3Array()
	var fill_i := PackedInt32Array()
	var bord_v := PackedVector3Array()
	var bord_i := PackedInt32Array()

	var min_gx := int(floor((origin.x - max_range) / CELL))
	var max_gx := int(ceil( (origin.x + max_range) / CELL))
	var min_gy := int(floor((origin.y - max_range) / CELL))
	var max_gy := int(ceil( (origin.y + max_range) / CELL))

	for gx in range(min_gx, max_gx + 1):
		for gy in range(min_gy, max_gy + 1):
			var cx := (gx + 0.5) * CELL
			var cy := (gy + 0.5) * CELL
			var px := clampf(origin.x, cx - half, cx + half)
			var py := clampf(origin.y, cy - half, cy + half)
			if Vector2(px, py).distance_to(origin) > max_range:
				continue
			var to_tile := Vector2(cx, cy) - origin
			if to_tile.length() < 0.001:
				continue
			if absf(dir_norm.angle_to(to_tile.normalized())) > half_rad:
				continue
			var fi := fill_v.size()
			var f  := BORDER
			fill_v.append(Vector3(cx - half + f, Y, cy - half + f))
			fill_v.append(Vector3(cx + half - f, Y, cy - half + f))
			fill_v.append(Vector3(cx + half - f, Y, cy + half - f))
			fill_v.append(Vector3(cx - half + f, Y, cy + half - f))
			fill_i.append_array([fi, fi+1, fi+2, fi, fi+2, fi+3])
			var strips := [
				[cx-half, cy-half,        cx+half,        cy-half+BORDER],
				[cx-half, cy+half-BORDER, cx+half,        cy+half],
				[cx-half, cy-half+BORDER, cx-half+BORDER, cy+half-BORDER],
				[cx+half-BORDER, cy-half+BORDER, cx+half, cy+half-BORDER],
			]
			for s in strips:
				var x0: float = s[0]; var z0: float = s[1]
				var x1: float = s[2]; var z1: float = s[3]
				var bi := bord_v.size()
				bord_v.append(Vector3(x0, Y + 0.001, z0))
				bord_v.append(Vector3(x1, Y + 0.001, z0))
				bord_v.append(Vector3(x1, Y + 0.001, z1))
				bord_v.append(Vector3(x0, Y + 0.001, z1))
				bord_i.append_array([bi, bi+1, bi+2, bi, bi+2, bi+3])

	var mesh := ArrayMesh.new()
	var fa := []; fa.resize(Mesh.ARRAY_MAX)
	fa[Mesh.ARRAY_VERTEX] = fill_v; fa[Mesh.ARRAY_INDEX] = fill_i
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, fa)
	var ba := []; ba.resize(Mesh.ARRAY_MAX)
	ba[Mesh.ARRAY_VERTEX] = bord_v; ba[Mesh.ARRAY_INDEX] = bord_i
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ba)

	mi.mesh = mesh
	mi.set_surface_override_material(0, mi.get_meta("fill_mat") if mi.has_meta("fill_mat") else null)
	mi.set_surface_override_material(1, mi.get_meta("bord_mat") if mi.has_meta("bord_mat") else null)
	mi.visible = fill_v.size() > 0

func calculate_push_landing(direction_target: Vector2, push_range: float) -> Vector2:
	var dir: Vector2 = (direction_target - enemy_pos).normalized()
	var target: Vector2 = enemy_pos + dir * push_range
	target = Vector2(clampf(target.x, 0.0, WORLD_W), clampf(target.y, 0.0, WORLD_H))
	return _clip_path_at_obstacle(enemy_pos, target)

## Tirón y ancla: el enemigo se arrastra hacia `toward` hasta `distance`
## (sin pasarse) y se frena en los obstáculos. push_enemy_to además lo deja a
## distancia mínima del jugador.
func calculate_drag_landing(toward: Vector2, distance: float) -> Vector2:
	var to_target: Vector2 = toward - enemy_pos
	var length := to_target.length()
	if length < 0.001:
		return enemy_pos
	var target: Vector2 = enemy_pos + to_target / length * minf(distance, length)
	return _clip_path_at_obstacle(enemy_pos, target)

# ── Módulos ───────────────────────────────────────────────────────────────────
## Los obstáculos que se pueden romper, golpear o crear son módulos: bloques de
## MODULE_SIZE × MODULE_SIZE (las piedras chicas del mapa también cuentan como
## uno). No tienen vida: una línea "break" los rompe de una. Las paredes
## grandes, los puentes y la plataforma son escenario.
const MODULE_SIZE := 1.0
## Dos módulos están "pegados" (para romperlos juntos) si sus centros están a
## esta distancia o menos (incluye los de al lado en diagonal).
const MODULE_TOUCH_DISTANCE := MODULE_SIZE * 1.6
## Holgura para considerar que un módulo lanzado cae "encima" de alguien.
const MODULE_ADJACENT_MARGIN := 0.35
## Derrumbe: un módulo está pegado al enemigo si su borde queda a menos de un
## módulo de su huella. Así cuentan los vecinos del hueco que deja un muro que
## pasa por encima del enemigo (build_modules saltea los lugares ocupados).
const MODULE_COLLAPSE_MARGIN := MODULE_SIZE + 0.1

var _module_mat: StandardMaterial3D

static func is_module(obs: Dictionary) -> bool:
	return obs.get("module", false)

## Muestra el alcance (romper, golpear o crear) alrededor del jugador.
func start_module_selection(reach: float) -> void:
	_show_disc(_attack_disc, player_pos, reach + _player_shadow_radius)

func clear_module_selection() -> void:
	_attack_disc.visible = false
	_push_disc.visible = false
	clear_enemy_highlight()

## Derrumbe: resalta al enemigo y el alcance.
func start_collapse_selection(reach: float) -> void:
	start_push_enemy_selection(reach)

## Lanzar módulo: muestra hasta dónde se puede tirar.
func start_module_throw_target(throw_range: float) -> void:
	_show_disc(_attack_disc, player_pos, throw_range)

## Módulos pegados al enemigo (los que le caen encima con un derrumbe).
func modules_adjacent_to_enemy() -> Array:
	var result: Array = []
	for obs in solid_obstacles:
		if is_module(obs) and _obstacle_edge_distance(obs, enemy_pos) <= _enemy_shadow_radius + MODULE_COLLAPSE_MARGIN:
			result.append(obs)
	return result

## Derrumbe: los módulos pegados al enemigo se le caen encima y se rompen.
## Devuelve cuántos fueron.
func collapse_modules_on_enemy() -> int:
	var fallen := modules_adjacent_to_enemy()
	for obs in fallen:
		_remove_module(obs)
	if not fallen.is_empty():
		_obstacles_changed()
	return fallen.size()

## Lanza el módulo a `target` (vuela por encima de todo): al caer se rompe y le
## pega a quien esté ahí. Devuelve {"enemy": bool, "player": bool}.
func throw_module(obs: Dictionary, target: Vector2) -> Dictionary:
	var reach := MODULE_SIZE * 0.5 + MODULE_ADJACENT_MARGIN
	var hits := {
		"enemy": target.distance_to(enemy_pos) <= reach + _enemy_shadow_radius,
		"player": target.distance_to(player_pos) <= reach + _player_shadow_radius,
	}
	solid_obstacles.erase(obs)
	_obstacles_changed()
	var node = obs.get("node")
	if is_instance_valid(node):
		if node.is_inside_tree():
			var tween: Tween = node.create_tween()
			var mid := Vector3((node.position.x + target.x) * 0.5, 3.0, (node.position.z + target.y) * 0.5)
			tween.tween_property(node, "position", mid, 0.18)
			tween.tween_property(node, "position", Vector3(target.x, MODULE_SIZE * 0.5, target.y), 0.18)
			tween.tween_callback(node.queue_free)
		else:
			node.free()
	return hits

func _remove_module(obs: Dictionary) -> void:
	var node = obs.get("node")
	if is_instance_valid(node):
		node.queue_free()
	solid_obstacles.erase(obs)

## El módulo bajo `pos` (o {} si no hay).
func get_module_at(pos: Vector2) -> Dictionary:
	for obs in solid_obstacles:
		if is_module(obs) and _obstacle_edge_distance(obs, pos) <= CLICK_MARGIN:
			return obs
	return {}

## Distancia del jugador al borde del obstáculo, contando desde su huella.
func obstacle_gap(obs: Dictionary) -> float:
	return maxf(0.0, _obstacle_edge_distance(obs, player_pos) - _player_shadow_radius)

func _obstacle_edge_distance(obs: Dictionary, pos: Vector2) -> float:
	var c: Vector2 = obs["pos"]
	if obs.has("box"):
		var h: Vector2 = obs["box"] * 0.5
		var d := Vector2(maxf(absf(pos.x - c.x) - h.x, 0.0), maxf(absf(pos.y - c.y) - h.y, 0.0))
		return d.length()
	return maxf(0.0, pos.distance_to(c) - float(obs["radius"]))

## Levanta hasta `count` módulos en fila, centrada en `center` y perpendicular
## a la línea jugador → center (un muro de frente). Los lugares ocupados (por
## un actor, otro obstáculo o fuera del mapa) se saltean. Devuelve cuántos creó.
func build_modules(center: Vector2, count: int) -> int:
	var dir: Vector2 = center - player_pos
	dir = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	var built := 0
	for i in count:
		var p: Vector2 = center + perp * (float(i) - float(count - 1) * 0.5) * MODULE_SIZE
		if _module_fits(p):
			_add_module(p)
			built += 1
	if built > 0:
		_obstacles_changed()
	return built

func _module_fits(p: Vector2) -> bool:
	var half := MODULE_SIZE * 0.5
	if p.x < half or p.y < half or p.x > WORLD_W - half or p.y > WORLD_H - half:
		return false
	if p.distance_to(player_pos) < _player_shadow_radius + half:
		return false
	if p.distance_to(enemy_pos) < _enemy_shadow_radius + half:
		return false
	for obs in solid_obstacles:
		if _obstacle_edge_distance(obs, p) < half * 0.9:
			return false
	return true

func _add_module(p: Vector2) -> Dictionary:
	if _module_mat == null:
		_module_mat = StandardMaterial3D.new()
		_module_mat.albedo_color = Color(0.46, 0.42, 0.36)
		_module_mat.roughness = 0.95
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(MODULE_SIZE, MODULE_SIZE, MODULE_SIZE)
	mi.mesh = box
	mi.position = Vector3(p.x, MODULE_SIZE * 0.5, p.y)
	mi.material_override = _module_mat
	add_child(mi)
	var obs := {"pos": p, "box": Vector2(MODULE_SIZE, MODULE_SIZE), "type": "solid", "module": true, "node": mi}
	solid_obstacles.append(obs)
	return obs

## Rompe `first` y los módulos pegados a él (los más cercanos primero), hasta
## `count` en total. Devuelve cuántos rompió.
func break_modules(first: Dictionary, count: int) -> int:
	var group: Array = [first]
	if first.has("log_id"):
		# Un tronco tirado se rompe entero, con una sola carta.
		group = solid_obstacles.filter(func(o): return o.get("log_id", -1) == first["log_id"])
		count = 0
	while group.size() < count:
		var best: Dictionary = {}
		var best_dist := INF
		for obs in solid_obstacles:
			if not is_module(obs) or group.any(func(g): return is_same(g, obs)):
				continue
			var touching: bool = group.any(func(g): return (g["pos"] as Vector2).distance_to(obs["pos"]) <= MODULE_TOUCH_DISTANCE)
			var dist: float = (first["pos"] as Vector2).distance_to(obs["pos"])
			if touching and dist < best_dist:
				best = obs
				best_dist = dist
		if best.is_empty():
			break
		group.append(best)
	for obs in group:
		_remove_module(obs)
	_obstacles_changed()
	return group.size()

## Golpe de módulo: lo desliza en `dir` hasta `distance` o hasta chocar con un
## actor u otro obstáculo. Un tramo de tronco arrastra al tronco entero (ariete).
## Si choca un árbol con el jugador arriba, lo tira.
## Devuelve {"hit": "enemy" | "player" | "", "pos": Vector2, "tree": Dictionary}.
func slide_module(obs: Dictionary, dir: Vector2, distance: float) -> Dictionary:
	var group: Array = [obs]
	if obs.has("log_id"):
		group = solid_obstacles.filter(func(o): return o.get("log_id", -1) == obs["log_id"])
	var step: Vector2 = dir.normalized() * distance
	var best_t := 1.0
	var hit := ""
	var hit_tree: Dictionary = {}
	for member in group:
		var from: Vector2 = member["pos"]
		var to: Vector2 = from + step
		var half := _module_half(member)
		best_t = minf(best_t, _bounds_t(from, to, half))
		for actor in [["enemy", enemy_pos, _enemy_shadow_radius], ["player", player_pos, _player_shadow_radius]]:
			var t := _first_contact_circle(from, to, actor[1], actor[2] + half)
			if t >= 0.0 and t < best_t:
				best_t = t
				hit = actor[0]
				hit_tree = {}
		for other in solid_obstacles:
			if group.any(func(g): return is_same(g, other)) or other.get("type", "solid") == "bridge":
				continue
			var t: float
			if other.has("box"):
				t = _segment_hit_t_box(from, to, other["pos"], other["box"] * 0.5 + Vector2(half, half))
			else:
				t = _first_contact_circle(from, to, other["pos"], float(other["radius"]) + half)
			if t >= 0.0 and t < best_t:
				best_t = t
				hit = ""
				hit_tree = other if other.get("type", "solid") == "tree" else {}
	var length := step.length()
	var travel := maxf(0.0, best_t * length - 0.02) if best_t < 1.0 else length
	var offset: Vector2 = step.normalized() * travel if length > 0.001 else Vector2.ZERO
	for member in group:
		var final: Vector2 = member["pos"] + offset
		member["pos"] = final
		var node = member.get("node")
		if is_instance_valid(node):
			var target := Vector3(final.x, node.position.y, final.y)
			if node.is_inside_tree():
				node.create_tween().tween_property(node, "position", target, 0.25)
			else:
				node.position = target
	_obstacles_changed()
	if not hit_tree.is_empty():
		_knock_player_off(hit_tree, false)  # el golpe sacude el árbol
	return {"hit": hit, "pos": obs["pos"], "tree": hit_tree}

## Hasta qué fracción del segmento se puede mover algo de radio `half` sin salir del mapa.
func _bounds_t(from: Vector2, to: Vector2, half: float) -> float:
	var t := 1.0
	var d := to - from
	for axis in 2:
		if absf(d[axis]) < 0.0001:
			continue
		var limit: float = (WORLD_W if axis == 0 else WORLD_H) - half if d[axis] > 0.0 else half
		t = minf(t, maxf(0.0, (limit - from[axis]) / d[axis]))
	return t

## Cono de dirección para golpear un módulo: se aleja del jugador.
func start_module_push_cone(module_pos: Vector2, push_range: float) -> void:
	_attack_disc.visible = false
	var dir: Vector2 = (module_pos - player_pos).normalized()
	_build_cone_disc(_push_disc, module_pos, dir, push_range, 55.0)

func is_pos_in_module_cone(module_pos: Vector2, pos: Vector2, push_range: float) -> bool:
	var to_pos: Vector2 = pos - module_pos
	if to_pos.length() < 0.001 or to_pos.length() > push_range:
		return false
	var dir: Vector2 = (module_pos - player_pos).normalized()
	return absf(dir.angle_to(to_pos.normalized())) <= deg_to_rad(55.0)

func _module_half(obs: Dictionary) -> float:
	if obs.has("box"):
		var b: Vector2 = obs["box"]
		return maxf(b.x, b.y) * 0.5
	return float(obs["radius"])

## Primer contacto del segmento con el círculo; si ya empieza tocándolo solo
## cuenta si se mueve hacia él (alejarse no es chocar).
static func _first_contact_circle(a: Vector2, b: Vector2, c: Vector2, r: float) -> float:
	var d := b - a
	if a.distance_to(c) < r:
		return 0.0 if d.dot(c - a) > 0.0 else -1.0
	var f := a - c
	var qa := d.dot(d)
	if qa < 0.000001:
		return -1.0
	var qb := 2.0 * f.dot(d)
	var qc := f.dot(f) - r * r
	var disc := qb * qb - 4.0 * qa * qc
	if disc < 0.0:
		return -1.0
	var t := (-qb - sqrt(disc)) / (2.0 * qa)
	return t if t >= 0.0 and t <= 1.0 else -1.0

## Los obstáculos cambiaron: se recalculan los bloqueos (caminos y selección).
func _obstacles_changed() -> void:
	_blocked_cache.clear()
	_warm_next = 0

# ── Hechizos ──────────────────────────────────────────────────────────────────
## Zonas marcadas que caen al terminar la ronda en la que llegan a 0 rondas
## (Meteoro, Granizada...): [{"pos", "radius", "damage", "name", "rounds",
## "effect", "puddle_turns", "node", "label"}]. effect "" = no deja charco.
var delayed_zones: Array[Dictionary] = []
## Qué parte del daño del hechizo es el daño por turno del charco que deja.
const DELAYED_PUDDLE_TICK_FRACTION := 0.25

## Hechizos a un punto: muestra el alcance alrededor del jugador.
func start_spell_selection(spell_range: float) -> void:
	_show_disc(_attack_disc, player_pos, spell_range)

func clear_spell_selection() -> void:
	_attack_disc.visible = false
	clear_overwatch_selection()
	clear_enemy_highlight()

## Cambia el efecto de los charcos que toca el círculo (Chispa: grasa → fuego;
## Escarcha: agua → hielo). Devuelve cuántos cambió.
func convert_puddles(center: Vector2, radius: float, from_effects: Array, to_effect: String) -> int:
	var converted: Array = []
	for i in puddle_zones.size():
		var zone: Dictionary = puddle_zones[i]
		if not zone.get("effect", "wet") in from_effects:
			continue
		if center.distance_to(zone["pos"]) > radius + float(zone["radius"]):
			continue
		zone["effect"] = to_effect
		if not zone.get("lens", false):
			_rebuild_puddle_visual(i)
		converted.append(zone)
	# El charco nuevo de fuego prende los árboles que toca (y así se propaga).
	for zone in converted:
		if to_effect == "fire":
			ignite_trees_in_circle(zone["pos"], zone["radius"])
		elif to_effect in ["ice", "wet"]:
			extinguish_trees_in_circle(zone["pos"], zone["radius"])
	return converted.size()

## Charcos de esos efectos que toca el segmento (Descarga se propaga por el agua).
func puddles_on_segment(from: Vector2, to: Vector2, effects: Array) -> Array:
	var result: Array = []
	for zone in puddle_zones:
		if zone.get("effect", "wet") in effects and _segment_point_distance(from, to, zone["pos"]) <= float(zone["radius"]):
			result.append(zone)
	return result

static func is_pos_in_zones(pos: Vector2, zones: Array) -> bool:
	for zone in zones:
		if pos.distance_to(zone["pos"]) <= float(zone["radius"]):
			return true
	return false

## El segmento pasa por la huella del enemigo (rayos en línea).
func segment_hits_enemy(from: Vector2, to: Vector2) -> bool:
	return _segment_point_distance(from, to, enemy_pos) <= _enemy_shadow_radius

## El enemigo está dentro del cono (se cuenta su huella).
func is_enemy_in_cone(origin: Vector2, dir: Vector2, cone_range: float, half_angle_deg: float) -> bool:
	var to_enemy: Vector2 = enemy_pos - origin
	var dist := to_enemy.length()
	if dist > cone_range + _enemy_shadow_radius:
		return false
	if dist <= _enemy_shadow_radius:
		return true
	var slack := asin(clampf(_enemy_shadow_radius / dist, 0.0, 1.0))
	return absf(dir.normalized().angle_to(to_enemy)) <= deg_to_rad(half_angle_deg) + slack

## El enemigo queda dentro del círculo (se cuenta su huella).
func is_enemy_in_circle(center: Vector2, radius: float) -> bool:
	return center.distance_to(enemy_pos) <= radius + _enemy_shadow_radius

func is_player_in_circle(center: Vector2, radius: float) -> bool:
	return center.distance_to(player_pos) <= radius + _player_shadow_radius

static func _segment_point_distance(a: Vector2, b: Vector2, p: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.000001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

## Meteoro y compañía: marca la zona. Cae en resolve_delayed_zones cuando
## pasan `rounds` rondas; si effect no es "", deja ese charco.
func place_delayed_zone(pos: Vector2, radius: float, damage: int, zone_name: String,
		rounds: int = 1, effect: String = "", puddle_turns: int = 0) -> void:
	var mi := _make_disc(Color(1.0, 0.25, 0.1, 0.45))
	_build_tile_disc(mi, pos, radius, 0.0, HIGHLIGHT_Y)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.outline_size = 12
	label.position = Vector3(pos.x, 0.6, pos.y)
	add_child(label)
	var zone := {
		"pos": pos, "radius": radius, "damage": damage, "name": zone_name,
		"rounds": maxi(1, rounds), "effect": effect, "puddle_turns": puddle_turns,
		"node": mi, "label": label,
	}
	_update_delayed_label(zone)
	delayed_zones.append(zone)

## Pasa una ronda: caen las zonas que llegan a 0. Devuelve las que cayeron:
## [{"name", "damage", "effect", "tick_damage", "enemy": bool, "player": bool}].
## Las que cayeron dejan su charco.
func resolve_delayed_zones() -> Array:
	var results: Array = []
	for i in range(delayed_zones.size() - 1, -1, -1):
		var zone: Dictionary = delayed_zones[i]
		zone["rounds"] -= 1
		if zone["rounds"] > 0:
			_update_delayed_label(zone)
			continue
		var tick := roundi(float(zone["damage"]) * DELAYED_PUDDLE_TICK_FRACTION)
		results.push_front({
			"name": zone["name"], "damage": zone["damage"], "effect": zone["effect"], "tick_damage": tick,
			"enemy": is_enemy_in_circle(zone["pos"], zone["radius"]),
			"player": is_player_in_circle(zone["pos"], zone["radius"]),
		})
		if zone["effect"] != "":
			var puddle_damage := tick if zone["effect"] in ["fire", "poison", "blood"] else 0
			place_puddle(zone["pos"], zone["radius"], zone["effect"], zone["puddle_turns"], puddle_damage)
		for key in ["node", "label"]:
			var node = zone.get(key)
			if is_instance_valid(node):
				node.queue_free()
		delayed_zones.remove_at(i)
	return results

func _update_delayed_label(zone: Dictionary) -> void:
	var label = zone.get("label")
	if is_instance_valid(label):
		label.text = str(zone["rounds"])

## Parpadeo: se puede aparecer ahí (dentro del mapa, sin obstáculo y sin pisar
## al enemigo). Ignora lo que haya en el camino.
func can_blink_to(pos: Vector2) -> bool:
	if pos.x < 0.0 or pos.y < 0.0 or pos.x > WORLD_W or pos.y > WORLD_H:
		return false
	if pos.distance_to(enemy_pos) < MIN_SEPARATION:
		return false
	return not _pos_blocked(pos, _elevation_at(pos), _player_shadow_radius)

func blink_player_to(pos: Vector2) -> void:
	player_pos = pos
	player_elevation = _elevation_at(pos)
	_update_actor_positions()

# ── Árboles ───────────────────────────────────────────────────────────────────
## Un árbol se puede trepar (tree_climb), talar con una línea "break" (cae y
## queda un tronco tirado) o prender fuego (arde TREE_BURN_ROUNDS y desaparece).
## Si el jugador está arriba cuando pasa algo de eso, cae al pie del árbol.
const TREE_BURN_ROUNDS := 2
## El tronco tirado: tramos en fila, bajos (bloquean el paso, no la vista).
const LOG_SEGMENTS := 3
const LOG_SEGMENT_RADIUS := 0.45
## Hasta dónde llega el fuego de un árbol a los charcos de alrededor.
const TREE_FIRE_SPREAD_MARGIN := 0.5
## Charco de planta pegado a un árbol: sale así de más grande.
const TREE_VINE_RADIUS_MULT := 1.5
const TREE_VINE_REACH := 1.0

var _climbed_tree: Dictionary = {}
var _tree_landing_marker: MeshInstance3D
var _next_log_id := 0

## El árbol bajo `pos` (o {} si no hay).
func get_tree_at(pos: Vector2) -> Dictionary:
	for obs in solid_obstacles:
		if obs.get("type", "solid") == "tree" and _obstacle_edge_distance(obs, pos) <= CLICK_MARGIN:
			return obs
	return {}

static func is_tree_burning(tree: Dictionary) -> bool:
	return tree.get("burning", 0) > 0

## Dónde se puede caer desde el árbol: un lugar libre, o encima del enemigo.
func can_drop_at(pos: Vector2) -> bool:
	return can_blink_to(pos) or is_enemy_in_circle(pos, 0.0)

## Sube al árbol y marca dónde va a caer.
func climb_tree(tree: Dictionary, landing: Vector2) -> void:
	_climbed_tree = tree
	if _tree_landing_marker == null:
		_tree_landing_marker = _make_disc(Color(0.3, 0.9, 0.4, 0.5))
	_build_tile_disc(_tree_landing_marker, landing, 0.6, 0.0, HIGHLIGHT_Y)
	_tree_landing_marker.visible = true
	_update_actor_positions()

## Cae del árbol a `landing` (si cae sobre el enemigo, queda pegado a él).
## Devuelve si le cayó encima.
func drop_from_tree(landing: Vector2) -> bool:
	var hit := is_enemy_in_circle(landing, 0.0)
	var target := landing
	if hit:
		var away: Vector2 = landing - enemy_pos
		if away.length() < 0.001:
			away = player_pos - enemy_pos
		target = enemy_pos + (away.normalized() if away.length() > 0.001 else Vector2.RIGHT) * MIN_SEPARATION
		if not can_blink_to(target):
			target = player_pos  # sin lugar al lado del enemigo: cae al pie del árbol
	elif not can_blink_to(target):
		target = player_pos
	_leave_tree()
	blink_player_to(target)
	return hit

func is_player_in_tree() -> bool:
	return not _climbed_tree.is_empty()

func _leave_tree() -> void:
	_climbed_tree = {}
	if _tree_landing_marker != null:
		_tree_landing_marker.visible = false
	_update_actor_positions()

## Si el jugador está en ese árbol, lo baja al pie y avisa (player_knocked_off_tree).
func _knock_player_off(tree: Dictionary, burning: bool) -> void:
	if not is_same(_climbed_tree, tree):
		return
	_leave_tree()
	player_knocked_off_tree.emit(burning)

## Tala el árbol: cae hacia `dir` y queda un tronco tirado. Los tramos que
## caerían encima de alguien no se crean; si es el enemigo, le pega.
## Devuelve {"enemy_hit": bool}. Si el jugador estaba arriba, se cae.
func fell_tree(tree: Dictionary, dir: Vector2) -> Dictionary:
	_knock_player_off(tree, false)
	var base: Vector2 = tree["pos"]
	var node = tree.get("node")
	if is_instance_valid(node):
		node.queue_free()
	solid_obstacles.erase(tree)
	dir = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	var log_id := _next_log_id
	_next_log_id += 1
	var enemy_hit := false
	var step := LOG_SEGMENT_RADIUS * 2.0
	for i in LOG_SEGMENTS:
		var p: Vector2 = base + dir * (step * float(i))
		if is_enemy_in_circle(p, LOG_SEGMENT_RADIUS):
			enemy_hit = true
			continue
		if is_player_in_circle(p, LOG_SEGMENT_RADIUS):
			continue
		if p.x < 0.0 or p.y < 0.0 or p.x > WORLD_W or p.y > WORLD_H:
			continue
		_add_log_segment(p, dir, log_id)
	_obstacles_changed()
	return {"enemy_hit": enemy_hit}

func _add_log_segment(p: Vector2, dir: Vector2, log_id: int) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = LOG_SEGMENT_RADIUS * 0.8
	cyl.bottom_radius = LOG_SEGMENT_RADIUS * 0.8
	cyl.height = LOG_SEGMENT_RADIUS * 2.1
	mi.mesh = cyl
	mi.position = Vector3(p.x, LOG_SEGMENT_RADIUS * 0.8, p.y)
	mi.rotation = Vector3(0.0, -atan2(dir.y, dir.x), PI * 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.24, 0.14)
	mi.material_override = mat
	add_child(mi)
	solid_obstacles.append({
		"pos": p, "radius": LOG_SEGMENT_RADIUS, "type": "rock", "module": true,
		"log_id": log_id, "node": mi,
	})

## Prende fuego los árboles que toca el círculo. Devuelve cuántos.
func ignite_trees_in_circle(center: Vector2, radius: float) -> int:
	var count := 0
	for obs in solid_obstacles.duplicate():
		if obs.get("type", "solid") == "tree" and _obstacle_edge_distance(obs, center) <= radius:
			count += int(_ignite_tree(obs))
	return count

## Prende fuego los árboles dentro del cono (Aliento). Devuelve cuántos.
func ignite_trees_in_cone(origin: Vector2, dir: Vector2, cone_range: float, half_angle_deg: float) -> int:
	var count := 0
	for obs in solid_obstacles.duplicate():
		if obs.get("type", "solid") != "tree":
			continue
		var to_tree: Vector2 = obs["pos"] - origin
		var dist := to_tree.length()
		if dist > cone_range + float(obs["radius"]) or dist < 0.001:
			continue
		var slack := asin(clampf(float(obs["radius"]) / dist, 0.0, 1.0))
		if absf(dir.normalized().angle_to(to_tree)) <= deg_to_rad(half_angle_deg) + slack:
			count += int(_ignite_tree(obs))
	return count

func _ignite_tree(tree: Dictionary) -> bool:
	if is_tree_burning(tree):
		return false
	tree["burning"] = TREE_BURN_ROUNDS
	_paint_canopy(tree, true)
	_knock_player_off(tree, true)
	_spread_fire_from_tree(tree)
	return true

## Un árbol en llamas prende los charcos de grasa y planta que lo tocan (y
## esos charcos, a su vez, los árboles que toquen: el fuego se propaga).
func _spread_fire_from_tree(tree: Dictionary) -> void:
	convert_puddles(tree["pos"], float(tree["radius"]) + TREE_FIRE_SPREAD_MARGIN, ["grease", "vine"], "fire")

## Apaga los árboles en llamas que toca el círculo (hielo, agua). Devuelve cuántos.
func extinguish_trees_in_circle(center: Vector2, radius: float) -> int:
	var count := 0
	for obs in solid_obstacles:
		if obs.get("type", "solid") == "tree" and is_tree_burning(obs) and _obstacle_edge_distance(obs, center) <= radius:
			obs["burning"] = 0
			_paint_canopy(obs, false)
			count += 1
	return count

func _paint_canopy(tree: Dictionary, burning: bool) -> void:
	var canopy = tree.get("canopy")
	if not is_instance_valid(canopy):
		return
	var mat := StandardMaterial3D.new()
	if burning:
		mat.albedo_color = Color(1.0, 0.4, 0.05)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.35, 0.0)
	else:
		mat.albedo_color = Color(0.18, 0.45, 0.2)
	canopy.material_override = mat

## Hay un árbol (que no arde) a `reach` o menos de `pos` (Raíces, charcos de planta).
func is_tree_near(pos: Vector2, reach: float) -> bool:
	for obs in solid_obstacles:
		if obs.get("type", "solid") == "tree" and not is_tree_burning(obs) and _obstacle_edge_distance(obs, pos) <= reach:
			return true
	return false

## Pararrayos: el primer árbol que cruza el segmento, con la fracción donde lo
## toca: {"tree": Dictionary, "t": float} o {} si no cruza ninguno.
func first_tree_on_segment(from: Vector2, to: Vector2) -> Dictionary:
	var best := {}
	for obs in solid_obstacles:
		if obs.get("type", "solid") != "tree":
			continue
		var t := _first_contact_circle(from, to, obs["pos"], float(obs["radius"]))
		if t >= 0.0 and (best.is_empty() or t < best["t"]):
			best = {"tree": obs, "t": t}
	return best

func is_player_in_this_tree(tree: Dictionary) -> bool:
	return is_same(_climbed_tree, tree)

## Pasa una ronda: los árboles que arden se consumen y desaparecen.
func tick_trees() -> void:
	var changed := false
	for obs in solid_obstacles.duplicate():
		if not is_tree_burning(obs):
			continue
		_spread_fire_from_tree(obs)
		obs["burning"] -= 1
		if obs["burning"] <= 0:
			var node = obs.get("node")
			if is_instance_valid(node):
				node.queue_free()
			solid_obstacles.erase(obs)
			changed = true
	if changed:
		_obstacles_changed()

## Ancla: muestra el alcance del disparo alrededor del jugador.
func start_anchor_selection(shot_range: float) -> void:
	_show_disc(_attack_disc, player_pos, shot_range)

func push_enemy_to(landing: Vector2) -> void:
	var sep: Vector2 = landing - player_pos
	if sep.length() < MIN_SEPARATION:
		landing = player_pos + (sep.normalized() if sep.length() > 0.001 else Vector2(MIN_SEPARATION, 0.0)) * MIN_SEPARATION
	enemy_pos           = landing
	enemy_elevation     = _elevation_at(landing)
	_enemy_move_pending = true
	_update_actor_positions()

func check_traps_along_segment(from: Vector2, to: Vector2) -> int:
	var total := 0
	var triggered: Array = []
	var steps := maxi(2, int(from.distance_to(to) / 0.4))
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var pos: Vector2 = from.lerp(to, t)
		for trap in trap_zones:
			if trap in triggered:
				continue
			if movement_distance(trap["pos"], pos) <= trap["radius"]:
				total += trap["damage"]
				triggered.append(trap)
	for trap in triggered:
		var idx: int = trap_zones.find(trap)
		if idx >= 0 and idx < _trap_visuals.size():
			_trap_visuals[idx].queue_free()
			_trap_visuals.remove_at(idx)
		trap_zones.erase(trap)
	return total

# Devuelve {"trap_damage": int, "wet": bool} para un segmento de movimiento forzado.
# Agregar nuevas zonas acá para que cualquier movimiento forzado las active automáticamente.
func trigger_zone_effects_along(from: Vector2, to: Vector2) -> Dictionary:
	var fx := get_puddle_effects_along(from, to)
	fx["trap_damage"] = check_traps_along_segment(from, to)
	return fx

# ── Puddles ───────────────────────────────────────────────────────────────────
func _puddle_base_color(effect: String) -> Color:
	match effect:
		"fire":   return Color(1.0, 0.35, 0.05)
		"grease": return Color(0.55, 0.45, 0.05)
		"vine":   return Color(0.1, 0.70, 0.15)
		"blood":  return Color(0.70, 0.05, 0.05)
		"poison": return Color(0.45, 0.0, 0.65)
		"sand":       return Color(0.85, 0.75, 0.4)
		"ice":        return Color(0.6,  0.9,  1.0)
		"bloody_ice": return Color(0.55, 0.65, 0.9)
		"dark_smoke": return Color(0.2,  0.15, 0.25)
		_:            return Color(0.1, 0.4, 0.9)

func start_puddle_placement(throw_range: float, effect: String = "wet", puddle_radius: float = 1.0) -> void:
	_puddle_throw_range    = throw_range
	_puddle_preview_effect = effect
	_puddle_preview_radius = puddle_radius
	_puddle_preview_last_pos = Vector2(-999.0, -999.0)
	_puddle_preview.visible  = false
	var c := _puddle_base_color(effect)
	_puddle_disc.set_meta("fill_mat", _make_mat(Color(c.r, c.g, c.b, 0.22)))
	_puddle_disc.set_meta("bord_mat", _make_mat(Color(
		minf(c.r + 0.3, 1.0), minf(c.g + 0.3, 1.0), minf(c.b + 0.3, 1.0), 0.75)))
	_show_disc_with_los(_puddle_disc, player_pos, throw_range, player_elevation)

func clear_puddle_placement() -> void:
	_puddle_disc.visible    = false
	_puddle_preview.visible = false
	_puddle_preview_last_pos = Vector2(-999.0, -999.0)

func _puddle_interaction(a: String, b: String) -> String:
	const TABLE := {
		"wet+ice":    "ice",
		"blood+ice":  "bloody_ice",
		"blood+fire": "dark_smoke",
	}
	var k := a + "+" + b
	if TABLE.has(k): return TABLE[k]
	k = b + "+" + a
	if TABLE.has(k): return TABLE[k]
	return ""

## Deja un charco. turns: rondas que dura (0 = no se va nunca; ver
## tick_puddles). damage: daño por turno del estado que causa (0 = el de
## CombatState). Si pisa otro charco con el que reacciona (_puddle_interaction),
## en la intersección queda un charco "lente" con el efecto combinado, que dura
## lo que el más corto de los dos.
##
## Cada zona: {"id", "pos", "radius", "effect", "turns", "damage", "lens",
## "excl"}; excl son los ids de los charcos cuyo disco se recorta del dibujo.
func place_puddle(pos: Vector2, radius: float, effect: String = "wet", turns: int = 0, damage: int = 0) -> void:
	var r2 := float(radius)
	if effect == "vine" and is_tree_near(pos, r2 + TREE_VINE_REACH):
		r2 *= TREE_VINE_RADIUS_MULT  # las plantas crecen más al lado de un árbol
	var new_id := _next_puddle_id
	_next_puddle_id += 1
	var new_excl: Array = []
	var to_rebuild: Array[int] = []

	for i in range(puddle_zones.size()):
		var existing: Dictionary = puddle_zones[i]
		var r1: float  = existing["radius"]
		var c1: Vector2 = existing["pos"]
		var dist: float = c1.distance_to(pos)
		if dist >= r1 + r2:
			continue
		var combined := _puddle_interaction(existing.get("effect", "wet"), effect)
		if combined == "":
			continue

		# El charco existente se redibuja sin la parte que ocupa el nuevo.
		existing["excl"].append(new_id)
		to_rebuild.append(i)

		# Zona de interacción en forma de lente
		var ipos: Vector2  = c1.lerp(pos, r1 / (r1 + r2))
		var ir: float      = maxf(0.5, (r1 + r2 - dist) * 0.5)
		puddle_zones.append({
			"id": _next_puddle_id, "pos": ipos, "radius": ir, "effect": combined,
			"turns": _shorter_turns(existing["turns"], turns),
			"damage": maxi(existing["damage"], damage), "lens": true, "excl": [],
			"parents": [existing["id"], new_id],
		})
		_next_puddle_id += 1
		_add_puddle_visual_lens(c1, r1, pos, r2, combined)

		new_excl.append(existing["id"])

	puddle_zones.append({
		"id": new_id, "pos": pos, "radius": r2, "effect": effect,
		"turns": turns, "damage": damage, "lens": false, "excl": new_excl,
	})
	_puddle_visuals.append(_make_puddle_visual(pos, r2, effect, _puddle_exclusions(puddle_zones.back())))
	for i in to_rebuild:
		_rebuild_puddle_visual(i)
	if effect == "fire":
		ignite_trees_in_circle(pos, r2)
	elif effect in ["ice", "wet"]:
		extinguish_trees_in_circle(pos, r2)

## Pasa una ronda: los charcos con duración pierden una y los que llegan a 0
## desaparecen (con sus lentes). Los que los recortaban se redibujan enteros.
func tick_puddles() -> void:
	var removed: Array = []
	for zone in puddle_zones:
		if zone["turns"] > 0:
			zone["turns"] -= 1
			if zone["turns"] == 0:
				removed.append(zone["id"])
	if removed.is_empty():
		return
	for i in range(puddle_zones.size() - 1, -1, -1):
		if puddle_zones[i]["id"] in removed:
			_puddle_visuals[i].queue_free()
			_puddle_visuals.remove_at(i)
			puddle_zones.remove_at(i)
	for i in puddle_zones.size():
		var excl: Array = puddle_zones[i]["excl"]
		var kept := excl.filter(func(id): return not id in removed)
		if kept.size() != excl.size():
			puddle_zones[i]["excl"] = kept
			_rebuild_puddle_visual(i)

## El charco (no combinado) que hay en `pos`, o {} si no hay.
func get_puddle_at(pos: Vector2) -> Dictionary:
	for zone in puddle_zones:
		if not zone.get("lens", false) and pos.distance_to(zone["pos"]) <= float(zone["radius"]) + CLICK_MARGIN * 0.5:
			return zone
	return {}

## Saca un charco del mapa, con sus zonas combinadas; los que lo recortaban se
## redibujan enteros.
func remove_puddle(zone: Dictionary) -> void:
	var id: int = zone["id"]
	var removed: Array = [id]
	for other in puddle_zones:
		if other.get("lens", false) and id in other.get("parents", []):
			removed.append(other["id"])
	for i in range(puddle_zones.size() - 1, -1, -1):
		if puddle_zones[i]["id"] in removed:
			_puddle_visuals[i].queue_free()
			_puddle_visuals.remove_at(i)
			puddle_zones.remove_at(i)
	for i in puddle_zones.size():
		var excl: Array = puddle_zones[i]["excl"]
		var kept := excl.filter(func(e): return not e in removed)
		if kept.size() != excl.size():
			puddle_zones[i]["excl"] = kept
			_rebuild_puddle_visual(i)

## Traslado de charco: lo saca de donde está y lo deja en `to`, con el mismo
## efecto, radio, rondas que le quedan y daño. Devuelve el charco nuevo.
func move_puddle(zone: Dictionary, to: Vector2) -> Dictionary:
	remove_puddle(zone)
	place_puddle(to, zone["radius"], zone["effect"], zone["turns"], zone["damage"])
	for i in range(puddle_zones.size() - 1, -1, -1):
		if not puddle_zones[i].get("lens", false):
			return puddle_zones[i]
	return {}

## Traslado de charco, paso 2: dónde puede caer (alrededor del charco elegido).
func start_puddle_hop_landing(puddle_pos: Vector2, hop_range: float) -> void:
	_show_disc(_attack_disc, puddle_pos, hop_range)

## Daño por turno de los estados de los charcos que cruza el segmento:
## {efecto: daño} (el mayor si hay varios); solo charcos con daño propio.
func get_puddle_damage_along(from: Vector2, to: Vector2) -> Dictionary:
	var result := {}
	if puddle_zones.is_empty():
		return result
	var steps := maxi(2, int(from.distance_to(to) / 0.3))
	for i in range(steps + 1):
		var pos: Vector2 = from.lerp(to, float(i) / float(steps))
		for puddle in puddle_zones:
			var dmg: int = puddle.get("damage", 0)
			if dmg > 0 and pos.distance_to(puddle["pos"]) <= puddle["radius"]:
				var effect: String = puddle.get("effect", "wet")
				result[effect] = maxi(int(result.get(effect, 0)), dmg)
	return result

## 0 es "para siempre": gana el otro.
static func _shorter_turns(a: int, b: int) -> int:
	if a == 0:
		return b
	if b == 0:
		return a
	return mini(a, b)

func _puddle_exclusions(zone: Dictionary) -> Array:
	var result: Array = []
	for other in puddle_zones:
		if other["id"] in zone["excl"]:
			result.append({"pos": other["pos"], "radius": other["radius"]})
	return result

func _rebuild_puddle_visual(i: int) -> void:
	var zone: Dictionary = puddle_zones[i]
	_puddle_visuals[i].queue_free()
	_puddle_visuals[i] = _make_puddle_visual(zone["pos"], zone["radius"], zone["effect"], _puddle_exclusions(zone))

func _make_puddle_visual(pos: Vector2, radius: float, effect: String = "wet", exclusions: Array = []) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var base := _puddle_base_color(effect)
	mi.set_meta("fill_mat", _make_mat(Color(base.r, base.g, base.b, 0.35)))
	mi.set_meta("bord_mat", _make_mat(Color(
		minf(base.r + 0.2, 1.0), minf(base.g + 0.2, 1.0), minf(base.b + 0.2, 1.0), 0.80)))
	add_child(mi)
	_build_tile_disc(mi, pos, radius, 0.0, 0.013, exclusions)
	return mi

func _add_puddle_visual_lens(c1: Vector2, r1: float, c2: Vector2, r2: float, effect: String) -> void:
	var mi := MeshInstance3D.new()
	var base := _puddle_base_color(effect)
	mi.set_meta("fill_mat", _make_mat(Color(base.r, base.g, base.b, 1.0)))
	mi.set_meta("bord_mat", _make_mat(Color(
		minf(base.r + 0.15, 1.0), minf(base.g + 0.15, 1.0), minf(base.b + 0.15, 1.0), 1.0)))
	add_child(mi)
	_build_lens_disc(mi, c1, r1, c2, r2, 0.016)
	_puddle_visuals.append(mi)

func _build_lens_disc(mi: MeshInstance3D, c1: Vector2, r1: float, c2: Vector2, r2: float, y: float) -> void:
	const CELL   := 0.08
	const BORDER := 0.010
	var half     := CELL * 0.5
	var fill_v   := PackedVector3Array(); var fill_i := PackedInt32Array()
	var bord_v   := PackedVector3Array(); var bord_i := PackedInt32Array()
	var min_x := maxf(c1.x - r1, c2.x - r2)
	var max_x := minf(c1.x + r1, c2.x + r2)
	var min_y := maxf(c1.y - r1, c2.y - r2)
	var max_y := minf(c1.y + r1, c2.y + r2)
	for gx in range(int(floor(min_x / CELL)), int(ceil(max_x / CELL)) + 1):
		for gy in range(int(floor(min_y / CELL)), int(ceil(max_y / CELL)) + 1):
			var cx := (gx + 0.5) * CELL
			var cy := (gy + 0.5) * CELL
			if Vector2(cx, cy).distance_to(c1) > r1: continue
			if Vector2(cx, cy).distance_to(c2) > r2: continue
			var fi := fill_v.size()
			fill_v.append(Vector3(cx-half+BORDER, y,       cy-half+BORDER))
			fill_v.append(Vector3(cx+half-BORDER, y,       cy-half+BORDER))
			fill_v.append(Vector3(cx+half-BORDER, y,       cy+half-BORDER))
			fill_v.append(Vector3(cx-half+BORDER, y,       cy+half-BORDER))
			fill_i.append_array([fi, fi+1, fi+2, fi, fi+2, fi+3])
			for s: Array in [
				[cx-half, cy-half,        cx+half,        cy-half+BORDER],
				[cx-half, cy+half-BORDER, cx+half,        cy+half],
				[cx-half, cy-half+BORDER, cx-half+BORDER, cy+half-BORDER],
				[cx+half-BORDER, cy-half+BORDER, cx+half, cy+half-BORDER],
			]:
				var bi := bord_v.size()
				bord_v.append(Vector3(s[0], y+0.001, s[1])); bord_v.append(Vector3(s[2], y+0.001, s[1]))
				bord_v.append(Vector3(s[2], y+0.001, s[3])); bord_v.append(Vector3(s[0], y+0.001, s[3]))
				bord_i.append_array([bi, bi+1, bi+2, bi, bi+2, bi+3])
	_apply_two_surface_mesh(mi, fill_v, fill_i, bord_v, bord_i)

func is_segment_in_puddle(from: Vector2, to: Vector2) -> bool:
	if puddle_zones.is_empty():
		return false
	var steps := maxi(2, int(from.distance_to(to) / 0.3))
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var pos: Vector2 = from.lerp(to, t)
		for puddle in puddle_zones:
			if puddle.get("effect", "wet") == "wet" and pos.distance_to(puddle["pos"]) <= puddle["radius"]:
				return true
	return false

func get_puddle_effects_along(from: Vector2, to: Vector2) -> Dictionary:
	var result := {}
	if puddle_zones.is_empty():
		return result
	var steps := maxi(2, int(from.distance_to(to) / 0.3))
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var pos: Vector2 = from.lerp(to, t)
		for puddle in puddle_zones:
			if pos.distance_to(puddle["pos"]) <= puddle["radius"]:
				result[puddle.get("effect", "wet")] = true
	return result

# ── Overwatch ─────────────────────────────────────────────────────────────────
func start_overwatch_selection(cone_range: float, half_angle: float) -> void:
	_overwatch_selection_active = true
	_overwatch_selection_range  = cone_range
	_overwatch_selection_angle  = half_angle
	_overwatch_preview_last_dir = Vector2.ZERO

func clear_overwatch_selection() -> void:
	_overwatch_selection_active      = false
	_overwatch_preview_disc.visible  = false
	_overwatch_preview_last_dir      = Vector2.ZERO

func place_overwatch(origin: Vector2, dir: Vector2, cone_range: float, half_angle: float) -> void:
	_overwatch_zone.set_meta("fill_mat", _make_mat(Color(1.0, 0.85, 0.1, 0.22)))
	_overwatch_zone.set_meta("bord_mat", _make_mat(Color(1.0, 1.0, 0.35, 0.70)))
	_build_cone_disc(_overwatch_zone, origin, dir, cone_range, half_angle)

func clear_overwatch_zone() -> void:
	_overwatch_zone.visible = false

func is_segment_in_overwatch_cone(from: Vector2, to: Vector2, origin: Vector2, dir: Vector2, cone_range: float, half_angle_deg: float) -> bool:
	var half_rad := deg_to_rad(half_angle_deg)
	var steps    := maxi(2, int(from.distance_to(to) / 0.3))
	for i in range(steps + 1):
		var pos: Vector2 = from.lerp(to, float(i) / float(steps))
		var to_pos := pos - origin
		if to_pos.length() < 0.001 or to_pos.length() > cone_range:
			continue
		if absf(dir.angle_to(to_pos.normalized())) <= half_rad:
			return true
	return false
