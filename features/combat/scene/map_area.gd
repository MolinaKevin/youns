extends Node3D

signal position_selected(pos: Vector2)
signal player_anim_finished
signal enemy_anim_finished

# ── World bounds ──────────────────────────────────────────────────────────────
const WORLD_W := 60.0
const WORLD_H := 60.0

# ── Positions (XZ world space) ────────────────────────────────────────────────
var player_pos := Vector2(5.0, 55.0)
var enemy_pos  := Vector2(55.0, 5.0)

# ── Selection state ───────────────────────────────────────────────────────────
var selected_move_range   := 0.0
var selected_attack_range := 0.0
var grenade_landing       := Vector2(-1.0, -1.0)
var grenade_aoe_radius    := 0.0
var selected_trap_range   := 0.0
var trap_zones: Array = []
var _trap_visuals: Array = []
var enemy_hp := 35

# ── Pathfinding ───────────────────────────────────────────────────────────────
const PATH_CELL := 0.5
var _last_path: Array[Vector2] = []
var _last_path_cost: float = 0.0

# ── Obstacles (círculos en espacio mundo) ─────────────────────────────────────
var solid_obstacles := [
	{"pos": Vector2(29.5, 29.5), "radius": 2.0},
	{"pos": Vector2(12.0, 20.0), "radius": 1.5},
	{"pos": Vector2(47.0, 18.0), "radius": 1.5},
	{"pos": Vector2(20.0, 42.0), "radius": 3.0, "box": Vector2(6.0, 6.0)},
	{"pos": Vector2(48.0, 44.0), "radius": 1.5},
]

# ── Visual ────────────────────────────────────────────────────────────────────
const PLAYER_ZONE_RADIUS := 0.6

var _move_disc:       MeshInstance3D
var _move_disc_inner: MeshInstance3D
var _player_circle:   MeshInstance3D
var _attack_disc:     MeshInstance3D
var _grenade_disc:    MeshInstance3D
var _trap_disc:       MeshInstance3D
var _dest_marker:     MeshInstance3D
var _path_highlight:  MeshInstance3D
var _hover_cell:      MeshInstance3D
var _player_shadow:        MeshInstance3D
var _enemy_shadow:         MeshInstance3D
var _player_shadow_radius: float = 0.65
var _enemy_shadow_radius:  float = 0.65
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
var _enemy_highlight_mat: StandardMaterial3D
var _self_highlight:      MeshInstance3D
var _self_highlight_mat:  StandardMaterial3D
var _enemy_hover:         MeshInstance3D
var _enemy_hover_mat:     StandardMaterial3D
var _self_hover:          MeshInstance3D
var _self_hover_mat:      StandardMaterial3D

# ── Init ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_setup_ground()
	_move_disc       = _make_disc(Color(0.2,  0.45, 0.85, 0.35))
	_move_disc_inner = _make_disc(Color(0.55, 0.80, 1.0,  0.55))
	_player_circle   = _make_disc(Color(0.6,  0.85, 1.0,  0.50))
	_attack_disc     = _make_disc(Color(0.9,  0.35, 0.1,  0.40))
	_grenade_disc    = _make_disc(Color(0.9,  0.8,  0.1,  0.45))
	_trap_disc       = _make_disc(Color(0.75, 0.4,  0.75, 0.35))
	_dest_marker     = _make_disc(Color(0.2,  0.95, 0.3,  0.80))
	_path_highlight  = _make_disc(Color(0.3,  0.95, 0.45, 0.70))
	_hover_cell      = _make_disc(Color(1.0,  1.0,  1.0,  0.55))
	_player_shadow   = _make_disc(Color(0.3,  0.6,  1.0,  0.35))
	_enemy_shadow    = _make_disc(Color(1.0,  0.3,  0.2,  0.35))

	_enemy_highlight_mat = _make_mat(Color(1.0, 0.25, 0.1, 0.65))
	_enemy_highlight = MeshInstance3D.new()
	_enemy_highlight.visible = false
	add_child(_enemy_highlight)

	_self_highlight_mat = _make_mat(Color(0.2, 0.75, 1.0, 0.55))
	_self_highlight = MeshInstance3D.new()
	_self_highlight.visible = false
	add_child(_self_highlight)

	_enemy_hover_mat = _make_mat(Color(1.0, 0.75, 0.1, 0.9))
	_enemy_hover = MeshInstance3D.new()
	_enemy_hover.visible = false
	add_child(_enemy_hover)

	_self_hover_mat = _make_mat(Color(0.5, 1.0, 1.0, 0.9))
	_self_hover = MeshInstance3D.new()
	_self_hover.visible = false
	add_child(_self_hover)

	_setup_obstacles()
	_setup_actors()

func _setup_obstacles() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.25, 0.20)
	mat.roughness    = 0.9
	for obs in solid_obstacles:
		var pos: Vector2 = obs["pos"]
		var mi           := MeshInstance3D.new()
		mi.material_override = mat
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
		add_child(mi)

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

func _show_disc(mi: MeshInstance3D, center: Vector2, radius: float, _unused: int = 0) -> void:
	_build_tile_disc(mi, center, radius, 0.0, 0.02)

func _show_disc_ring(mi: MeshInstance3D, center: Vector2, radius: float, inner: float) -> void:
	_build_tile_disc(mi, center, radius, inner, 0.02)

func _build_tile_disc(mi: MeshInstance3D, center: Vector2, radius: float, inner_radius: float, y: float) -> void:
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
			var d  := Vector2(cx, cy).distance_to(center)
			if d > radius or d < inner_radius:
				continue

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

func _show_smooth_circle(mi: MeshInstance3D, center: Vector2, radius: float, segments: int = 64) -> void:
	var verts   := PackedVector3Array()
	var indices := PackedInt32Array()
	verts.append(Vector3(center.x, 0.01, center.y))
	for i in range(segments):
		var a := float(i) / float(segments) * TAU
		verts.append(Vector3(center.x + cos(a) * radius, 0.01, center.y + sin(a) * radius))
	for i in range(segments):
		indices.append_array([0, i + 1, (i + 1) % segments + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX]  = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mi.mesh    = mesh
	mi.visible = true

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
	_player_shadow_radius = data.combat_shadow_radius
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
	if _player_current_anim == target:
		return
	if _player_current_anim in _player_bodies:
		_player_bodies[_player_current_anim].visible = false
	_player_current_anim = target
	var is_priority := anim_key in _PRIORITY_ANIMS
	if target not in _player_bodies:
		if is_priority:
			player_anim_finished.emit()
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
		player_anim_finished.emit()

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
	_enemy_shadow_radius = data.combat_shadow_radius
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
			enemy_anim_finished.emit()
		return
	var target := anim_key if anim_key in _enemy_bodies else "idle"
	if is_priority and target != anim_key:
		enemy_anim_finished.emit()
		return
	if _enemy_current_anim == target and not is_priority:
		return
	if _enemy_current_anim in _enemy_bodies:
		_enemy_bodies[_enemy_current_anim].visible = false
	_enemy_current_anim = target
	if target not in _enemy_bodies:
		if is_priority:
			enemy_anim_finished.emit()
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
		enemy_anim_finished.emit()

func _update_actor_positions() -> void:
	_player_target = Vector3(player_pos.x, 0.0, player_pos.y)
	_enemy_target  = Vector3(enemy_pos.x,   0.0, enemy_pos.y)

# ── Input ─────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera: return

	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var from := camera.project_ray_origin(event.position)
		var dir  := camera.project_ray_normal(event.position)
		if abs(dir.y) < 0.001: return
		var t := -from.y / dir.y
		if t < 0.0: return
		var hit := from + dir * t
		var pos := Vector2(clampf(hit.x, 0.0, WORLD_W), clampf(hit.z, 0.0, WORLD_H))
		position_selected.emit(pos)

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		_update_hover(get_viewport().get_mouse_position(), camera)
	var step := ACTOR_MOVE_SPEED * delta

	var prev_pos := _player_body.position
	_player_body.position = _player_body.position.move_toward(_player_target, step)
	var dist_moved := prev_pos.distance_to(_player_body.position)

	if _player_current_anim not in _PRIORITY_ANIMS:
		var face_dir: Vector3
		if dist_moved > 0.001:
			face_dir = _player_target - prev_pos
			play_player_anim("run" if "run" in _player_bodies else "walk")
		else:
			face_dir = _enemy_body.position - _player_body.position
			play_player_anim("idle")
		face_dir.y = 0.0
		if face_dir.length() > 0.001:
			var target_angle := atan2(face_dir.x, face_dir.z)
			_player_body.rotation.y = lerp_angle(_player_body.rotation.y, target_angle, _player_rotate_speed * delta)

	var prev_enemy := _enemy_body.position
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

	_show_disc(_player_shadow, Vector2(_player_body.position.x, _player_body.position.z), _player_shadow_radius)
	_show_disc(_enemy_shadow,  Vector2(_enemy_body.position.x,  _enemy_body.position.z),  _enemy_shadow_radius)

func _update_hover(screen_pos: Vector2, camera: Camera3D) -> void:
	var any_disc   := _move_disc.visible or _attack_disc.visible \
		or _trap_disc.visible or _grenade_disc.visible
	var any_target := _enemy_highlight.visible or _self_highlight.visible or _attack_disc.visible
	if not any_disc and not any_target:
		_hover_cell.visible  = false
		_enemy_hover.visible = false
		_self_hover.visible  = false
		return
	var from := camera.project_ray_origin(screen_pos)
	var dir  := camera.project_ray_normal(screen_pos)
	if abs(dir.y) < 0.001:
		_hover_cell.visible  = false
		_enemy_hover.visible = false
		_self_hover.visible  = false
		return
	var t := -from.y / dir.y
	if t < 0.0:
		_hover_cell.visible  = false
		_enemy_hover.visible = false
		_self_hover.visible  = false
		return
	var hit := from + dir * t
	var pos := Vector2(clampf(hit.x, 0.0, WORLD_W), clampf(hit.z, 0.0, WORLD_H))
	if any_disc:
		_show_single_cell(_hover_cell, pos)
	else:
		_hover_cell.visible = false
	_enemy_hover.visible = (_enemy_highlight.visible or _attack_disc.visible) and is_click_on_enemy(pos)
	_self_hover.visible  = _self_highlight.visible and is_click_on_player(pos)

func _show_single_cell(mi: MeshInstance3D, world_pos: Vector2) -> void:
	var cx: float = floor(world_pos.x / 0.08) * 0.08 + 0.04
	var cy: float = floor(world_pos.y / 0.08) * 0.08 + 0.04
	_build_tile_disc(mi, Vector2(cx, cy), 0.04, 0.0, 0.03)

# ── Helpers ───────────────────────────────────────────────────────────────────
func movement_distance(a: Vector2, b: Vector2) -> float:
	return a.distance_to(b)

func _in_bounds(pos: Vector2) -> bool:
	return pos.x >= 0.0 and pos.x <= WORLD_W and pos.y >= 0.0 and pos.y <= WORLD_H

# ── Move ──────────────────────────────────────────────────────────────────────
func start_move_selection(move_range: float) -> void:
	selected_move_range = move_range
	_show_reachable(_move_disc, _move_disc_inner, player_pos, move_range)
	_show_smooth_circle(_player_circle, player_pos, PLAYER_ZONE_RADIUS)

func _dijkstra_reachable(origin: Vector2, move_range: float) -> Dictionary:
	var start := _w2g(origin)
	var dist  := {}
	dist[start] = 0.0
	var queue: Array = [[0.0, start]]
	while not queue.is_empty():
		queue.sort_custom(func(a, b): return a[0] < b[0])
		var entry: Array    = queue.pop_front()
		var cur_cost: float = entry[0]
		var cur: Vector2i   = entry[1]
		if cur_cost > dist.get(cur, INF): continue
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dy == 0: continue
				var nb := cur + Vector2i(dx, dy)
				if not _g_in_bounds(nb) or _g_blocked(nb): continue
				var step: float = (1.414 if (dx != 0 and dy != 0) else 1.0) * PATH_CELL
				var nc: float   = cur_cost + step
				if nc <= move_range + 0.01 and nc < dist.get(nb, INF):
					dist[nb] = nc
					queue.append([nc, nb])
	return dist

func _show_reachable(outer: MeshInstance3D, inner: MeshInstance3D, origin: Vector2, move_range: float) -> void:
	const VCELL  := 0.08
	const BORDER := 0.010
	var half     := VCELL * 0.5

	var out_fv := PackedVector3Array(); var out_fi := PackedInt32Array()
	var out_bv := PackedVector3Array(); var out_bi := PackedInt32Array()
	var in_fv  := PackedVector3Array(); var in_fi  := PackedInt32Array()
	var in_bv  := PackedVector3Array(); var in_bi  := PackedInt32Array()

	var vgx0 := int(floor((origin.x - move_range) / VCELL))
	var vgx1 := int(ceil( (origin.x + move_range) / VCELL))
	var vgy0 := int(floor((origin.y - move_range) / VCELL))
	var vgy1 := int(ceil( (origin.y + move_range) / VCELL))

	for gx in range(vgx0, vgx1 + 1):
		for gy in range(vgy0, vgy1 + 1):
			var cx: float = (gx + 0.5) * VCELL
			var cy: float = (gy + 0.5) * VCELL
			var cell_pos := Vector2(cx, cy)
			if cell_pos.distance_to(origin) > move_range: continue
			if _tile_in_obstacle(cell_pos):               continue
			if not has_line_of_sight(origin, cell_pos):   continue
			var is_inner := cell_pos.distance_to(origin) <= PLAYER_ZONE_RADIUS
			var y: float = 0.022 if is_inner else 0.02
			var fv := in_fv if is_inner else out_fv
			var fi := in_fi if is_inner else out_fi
			var bv := in_bv if is_inner else out_bv
			var bi := in_bi if is_inner else out_bi
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

	_apply_two_surface_mesh(outer, out_fv, out_fi, out_bv, out_bi)
	_apply_two_surface_mesh(inner, in_fv,  in_fi,  in_bv,  in_bi)

func _tile_in_obstacle(pos: Vector2) -> bool:
	for obs in solid_obstacles:
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
	_move_disc_inner.visible = false
	_player_circle.visible   = false

func show_move_preview(pos: Vector2) -> void:
	_show_disc(_dest_marker, pos, 0.5)

func clear_move_preview() -> void:
	_dest_marker.visible = false

func show_path_preview(_from: Vector2, _to: Vector2) -> void:
	# Uses _last_path computed by compute_path()
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
			var fi := fill_v.size()
			fill_v.append(Vector3(cx-half+BORDER, 0.025, cy-half+BORDER))
			fill_v.append(Vector3(cx+half-BORDER, 0.025, cy-half+BORDER))
			fill_v.append(Vector3(cx+half-BORDER, 0.025, cy+half-BORDER))
			fill_v.append(Vector3(cx-half+BORDER, 0.025, cy+half-BORDER))
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
				bord_v.append(Vector3(x0, 0.026, z0)); bord_v.append(Vector3(x1, 0.026, z0))
				bord_v.append(Vector3(x1, 0.026, z1)); bord_v.append(Vector3(x0, 0.026, z1))
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
	if not _in_bounds(pos): return false
	if _last_path_cost > selected_move_range + 0.1: return false
	var sep := pos - enemy_pos
	if sep.length() < MIN_SEPARATION:
		pos = enemy_pos + (sep.normalized() if sep.length() > 0.001 else Vector2(MIN_SEPARATION, 0.0)) * MIN_SEPARATION
	player_pos = pos
	_last_path = []
	_last_path_cost = 0.0
	clear_move_selection()
	_update_actor_positions()
	return true

func get_path_cost(_pos: Vector2) -> float:
	return _last_path_cost

# ── A* Pathfinding ────────────────────────────────────────────────────────────
func compute_path(from: Vector2, to: Vector2) -> float:
	# Direct LOS → straight line, no A* needed
	if has_line_of_sight(from, to):
		_last_path      = [from, to]
		_last_path_cost = from.distance_to(to)
		return _last_path_cost

	_last_path = []
	_last_path_cost = INF

	var start := _w2g(from)
	var goal  := _w2g(to)

	var open   := {}       # Vector2i -> true  (open set)
	var came   := {}       # Vector2i -> Vector2i
	var g      := {}       # Vector2i -> float
	var f      := {}       # Vector2i -> float

	g[start] = 0.0
	f[start] = _heuristic(start, goal)
	open[start] = true

	while not open.is_empty():
		var cur: Vector2i = _lowest_f(open, f)
		if cur == goal:
			_last_path      = _reconstruct(came, cur, from, to)
			_last_path_cost = g[cur] * PATH_CELL
			return _last_path_cost
		open.erase(cur)
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dy == 0: continue
				var nb := cur + Vector2i(dx, dy)
				if not _g_in_bounds(nb): continue
				if _g_blocked(nb):       continue
				var step: float = 1.414 if (dx != 0 and dy != 0) else 1.0
				var tg: float   = g.get(cur, INF) + step
				if tg < g.get(nb, INF):
					came[nb] = cur
					g[nb]    = tg
					f[nb]    = tg + _heuristic(nb, goal)
					open[nb] = true

	return INF  # no path

func _w2g(pos: Vector2) -> Vector2i:
	return Vector2i(int(round(pos.x / PATH_CELL)), int(round(pos.y / PATH_CELL)))

func _g2w(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * PATH_CELL, cell.y * PATH_CELL)

func _g_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x <= int(WORLD_W / PATH_CELL) \
		and cell.y >= 0 and cell.y <= int(WORLD_H / PATH_CELL)

func _g_blocked(cell: Vector2i) -> bool:
	var wp := _g2w(cell)
	for obs in solid_obstacles:
		if obs.has("box"):
			var half: Vector2 = obs["box"] * 0.5 + Vector2(PATH_CELL, PATH_CELL) * 0.5
			var p: Vector2    = obs["pos"]
			if abs(wp.x - p.x) < half.x and abs(wp.y - p.y) < half.y:
				return true
		else:
			if wp.distance_to(obs["pos"]) < obs["radius"] + PATH_CELL * 0.5:
				return true
	return false

func _heuristic(a: Vector2i, b: Vector2i) -> float:
	var dx: int = abs(a.x - b.x)
	var dy: int = abs(a.y - b.y)
	return float(maxi(dx, dy)) + float(minf(dx, dy)) * 0.414

func _lowest_f(open: Dictionary, f: Dictionary) -> Vector2i:
	var best: Vector2i
	var best_f := INF
	for node in open:
		var fv: float = f.get(node, INF)
		if fv < best_f:
			best_f = fv
			best   = node
	return best

func _reconstruct(came: Dictionary, cur: Vector2i, from: Vector2, to: Vector2) -> Array[Vector2]:
	var path: Array[Vector2] = []
	var c := cur
	while came.has(c):
		path.push_front(_g2w(c))
		c = came[c]
	path.push_front(from)
	if not path.is_empty():
		path[-1] = to
	return path

# ── Attack ────────────────────────────────────────────────────────────────────
func start_attack_selection(attack_range: float) -> void:
	selected_attack_range = attack_range
	_show_disc(_attack_disc, player_pos, attack_range)
	_show_smooth_circle(_enemy_hover, enemy_pos, 1.1)
	_enemy_hover.set_surface_override_material(0, _enemy_hover_mat)
	_enemy_hover.visible = false

func clear_attack_selection() -> void:
	selected_attack_range = 0.0
	_attack_disc.visible  = false
	_enemy_hover.visible  = false

func is_enemy_in_attack_range(attack_range: float) -> bool:
	return movement_distance(player_pos, enemy_pos) <= attack_range \
		and has_line_of_sight(player_pos, enemy_pos)

func is_enemy_in_melee_range() -> bool:
	return movement_distance(player_pos, enemy_pos) <= 1.5

func is_player_in_melee_range() -> bool:
	return movement_distance(enemy_pos, player_pos) <= 1.5

# ── LOS ───────────────────────────────────────────────────────────────────────
func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	for obs in solid_obstacles:
		if obs.has("box"):
			if _segment_hits_box(from, to, obs["pos"], obs["box"] * 0.5):
				return false
		else:
			if _segment_hits_circle(from, to, obs["pos"], obs["radius"]):
				return false
	return true

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
	_show_smooth_circle(_enemy_highlight, enemy_pos, 2.0)
	_enemy_highlight.set_surface_override_material(0, _enemy_highlight_mat)
	_show_smooth_circle(_enemy_hover, enemy_pos, 1.1)
	_enemy_hover.set_surface_override_material(0, _enemy_hover_mat)
	_enemy_hover.visible = false

func clear_enemy_highlight() -> void:
	_enemy_highlight.visible = false
	_enemy_hover.visible     = false

func start_self_highlight() -> void:
	_show_smooth_circle(_self_highlight, player_pos, 1.5)
	_self_highlight.set_surface_override_material(0, _self_highlight_mat)
	_show_smooth_circle(_self_hover, player_pos, 0.9)
	_self_hover.set_surface_override_material(0, _self_hover_mat)
	_self_hover.visible = false

func clear_self_highlight() -> void:
	_self_highlight.visible = false
	_self_hover.visible     = false

func is_click_on_enemy(pos: Vector2) -> bool:
	return pos.distance_to(enemy_pos) <= 2.5

func is_click_on_player(pos: Vector2) -> bool:
	return pos.distance_to(player_pos) <= 2.0

# ── Enemy ─────────────────────────────────────────────────────────────────────
func set_enemy_hp(hp: int) -> void:
	enemy_hp = hp

func can_place_enemy(pos: Vector2) -> bool:
	return _in_bounds(pos)

func move_enemy_toward(target: Vector2, move_range: float) -> bool:
	var dist := movement_distance(enemy_pos, target)
	if dist < 0.01: return false
	var dir      := (target - enemy_pos).normalized()
	var new_pos  := enemy_pos + dir * minf(dist, move_range)
	new_pos.x = clampf(new_pos.x, 0.0, WORLD_W)
	new_pos.y = clampf(new_pos.y, 0.0, WORLD_H)
	var sep := new_pos - player_pos
	if sep.length() < MIN_SEPARATION:
		new_pos = player_pos + (sep.normalized() if sep.length() > 0.001 else Vector2(MIN_SEPARATION, 0.0)) * MIN_SEPARATION
	enemy_pos = new_pos
	_update_actor_positions()
	return true

# ── Traps ─────────────────────────────────────────────────────────────────────
func start_trap_placement(trap_range: float) -> void:
	selected_trap_range = trap_range
	_show_disc_with_los(_trap_disc, player_pos, trap_range)

func _show_disc_with_los(mi: MeshInstance3D, origin: Vector2, radius: float) -> void:
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
			if cell_pos.distance_to(origin) > radius:         continue
			if _tile_in_obstacle(cell_pos):                    continue
			if not has_line_of_sight(origin, cell_pos):        continue
			var y: float = 0.02
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
	selected_trap_range = 0.0
	_trap_disc.visible  = false

func place_trap(pos: Vector2, radius: int, damage: int, card_name: String) -> void:
	trap_zones.append({"pos": pos, "radius": float(radius), "damage": damage, "name": card_name})
	_add_trap_visual(pos, float(radius))

func _add_trap_visual(pos: Vector2, radius: float) -> void:
	var mi := MeshInstance3D.new()
	# Outer glow ring
	var outer_mat := _make_mat(Color(0.8, 0.2, 0.8, 0.25))
	var inner_mat := _make_mat(Color(1.0, 0.5, 1.0, 0.70))
	var segments  := 48
	var verts     := PackedVector3Array()
	var indices   := PackedInt32Array()
	# Fill circle
	verts.append(Vector3(pos.x, 0.015, pos.y))
	for i in range(segments):
		var a := float(i) / float(segments) * TAU
		verts.append(Vector3(pos.x + cos(a) * radius, 0.015, pos.y + sin(a) * radius))
	for i in range(segments):
		indices.append_array([0, i + 1, (i + 1) % segments + 1])
	var fa := []; fa.resize(Mesh.ARRAY_MAX)
	fa[Mesh.ARRAY_VERTEX] = verts; fa[Mesh.ARRAY_INDEX] = indices
	# Thin ring border
	var ring_w  := minf(0.15, radius * 0.15)
	var bverts  := PackedVector3Array()
	var bindices := PackedInt32Array()
	for i in range(segments):
		var a0 := float(i)       / float(segments) * TAU
		var a1 := float(i + 1)  / float(segments) * TAU
		var r_in  := radius - ring_w
		var r_out := radius
		var vi := bverts.size()
		bverts.append(Vector3(pos.x + cos(a0) * r_in,  0.016, pos.y + sin(a0) * r_in))
		bverts.append(Vector3(pos.x + cos(a0) * r_out, 0.016, pos.y + sin(a0) * r_out))
		bverts.append(Vector3(pos.x + cos(a1) * r_out, 0.016, pos.y + sin(a1) * r_out))
		bverts.append(Vector3(pos.x + cos(a1) * r_in,  0.016, pos.y + sin(a1) * r_in))
		bindices.append_array([vi, vi+1, vi+2, vi, vi+2, vi+3])
	var ba := []; ba.resize(Mesh.ARRAY_MAX)
	ba[Mesh.ARRAY_VERTEX] = bverts; ba[Mesh.ARRAY_INDEX] = bindices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, fa)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ba)
	mi.mesh = mesh
	mi.set_surface_override_material(0, outer_mat)
	mi.set_surface_override_material(1, inner_mat)
	add_child(mi)
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
		landing  = target + dir.rotated(randf_range(-PI / 5.0, PI / 5.0)) * bounce * 20.0
		landing  = Vector2(clampf(landing.x, 0.0, WORLD_W), clampf(landing.y, 0.0, WORLD_H))
	return _clip_path_at_obstacle(from, landing)

# Returns the point where the segment from→to first hits an obstacle, or to if clear.
func _clip_path_at_obstacle(from: Vector2, to: Vector2) -> Vector2:
	var closest_t := 1.0
	for obs in solid_obstacles:
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

func show_grenade_preview(landing: Vector2, aoe_radius: int) -> void:
	grenade_landing    = landing
	grenade_aoe_radius = float(aoe_radius)
	_show_disc(_grenade_disc, landing, grenade_aoe_radius)

func clear_grenade_preview() -> void:
	grenade_landing       = Vector2(-1.0, -1.0)
	grenade_aoe_radius    = 0.0
	_grenade_disc.visible = false

func is_enemy_in_explosion(center: Vector2, radius: int) -> bool:
	return movement_distance(center, enemy_pos) <= float(radius)
