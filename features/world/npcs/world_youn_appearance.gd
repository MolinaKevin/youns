class_name WorldYounAppearance
extends RefCounted

## Cuerpo visual de WorldYoun: instancia las escenas idle/walk/run (o el mesh
## estático si no hay ninguna) de `youn_data`, les aplica el material de
## textura si corresponde, y cambia cuál cuerpo está visible/animando. No
## sabe nada de IA, diálogo ni combate — `host` es el WorldYoun dueño
## exclusivo de esta instancia.

var host: WorldYoun
var _anim_bodies: Dictionary = {}
var _anim_current: String = ""

func _init(p_host: WorldYoun) -> void:
	host = p_host

## Instancia los cuerpos de `host.youn_data` dentro de `host.body_root`.
func setup() -> void:
	var youn_data := host.youn_data
	var mat: StandardMaterial3D = null
	if youn_data.texture:
		mat = StandardMaterial3D.new()
		mat.albedo_texture = youn_data.texture
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	for key in ["idle", "walk", "run"]:
		var packed: PackedScene = youn_data.get("scene_" + key)
		if not packed:
			continue
		var body: Node3D = packed.instantiate()
		body.scale = Vector3.ONE * youn_data.mesh_scale
		body.position.y = 0.0
		body.visible = false
		if mat:
			for mi in Node3DSearch.find_meshes(body):
				mi.material_override = mat
		host.body_root.add_child(body)
		_anim_bodies[key] = body

	if _anim_bodies.is_empty() and youn_data.mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = youn_data.mesh
		mi.scale = Vector3.ONE * youn_data.mesh_scale
		mi.position.y = youn_data.mesh_y_offset
		if mat:
			mi.material_override = mat
		host.body_root.add_child(mi)
	else:
		switch_anim("idle")

func switch_anim(key: String) -> void:
	var target := key if key in _anim_bodies else "idle"
	if _anim_current == target:
		return
	if _anim_current in _anim_bodies:
		_anim_bodies[_anim_current].visible = false
	_anim_current = target
	if target not in _anim_bodies:
		return
	var body: Node3D = _anim_bodies[target]
	body.visible = true
	var ap := Node3DSearch.find_anim_player(body)
	if ap:
		var list := ap.get_animation_list()
		if not list.is_empty():
			var anim := ap.get_animation(list[0])
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
			ap.play(list[0])
