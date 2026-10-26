class_name YounAppearance
extends RefCounted

## Cuerpo visual del compañero: instancia las escenas idle/walk/run/... de
## youn_data (o un modelo de primitivas si no trae ninguna) y cambia cuál
## cuerpo está visible/animando. No sabe nada de seguimiento ni de la burbuja
## de emociones — host es el Youn3D dueño exclusivo de esta instancia.

const PlaceholderModel := preload("res://features/world/party/placeholder_model.gd")

var host: Youn3D
var _anim_bodies: Dictionary = {}   # "idle" -> Node3D, "walk" -> Node3D, etc.
var _anim_current: String = ""

func _init(p_host: Youn3D) -> void:
	host = p_host

func load_model(data: YounData) -> void:
	for body in _anim_bodies.values():
		body.queue_free()
	_anim_bodies.clear()
	_anim_current = ""

	var mat: StandardMaterial3D = null
	if data.texture:
		mat = StandardMaterial3D.new()
		mat.albedo_texture = data.texture
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var scene_map: Dictionary = {
		"idle":    data.scene_idle,
		"walk":    data.scene_walk,
		"run":     data.scene_run,
		"attack":  data.scene_attack,
		"range":   data.scene_range,
		"damage":  data.scene_damage,
		"die":     data.scene_die,
		"evolve":  data.scene_evolve,
	}

	for key in scene_map:
		var packed: PackedScene = scene_map[key]
		if not packed:
			continue
		var body: Node3D = packed.instantiate()
		body.scale = Vector3.ONE * data.mesh_scale
		body.position.y = data.mesh_y_offset
		body.rotation.y = data.mesh_rotation_y
		body.visible = false
		host.add_child(body)
		if mat:
			for mesh in Node3DSearch.find_meshes(body):
				mesh.material_override = mat
		_anim_bodies[key] = body

	# Youn sin modelo todavía: uno de primitivas (PlaceholderModel), para que se vea.
	if _anim_bodies.is_empty():
		_anim_bodies["idle"] = PlaceholderModel.build(data)
		_anim_bodies["idle"].visible = false
		host.add_child(_anim_bodies["idle"])
	if DebugSettings.verbose_logging_enabled:
		print("YounAppearance loaded bodies: ", _anim_bodies.keys())
	switch_anim("idle")

func switch_anim(anim_key: String) -> void:
	# Si la animación pedida no existe, cae al idle
	var target := anim_key if anim_key in _anim_bodies else "idle"
	if _anim_current == target:
		return
	if _anim_current in _anim_bodies:
		_anim_bodies[_anim_current].visible = false
	_anim_current = target
	if target in _anim_bodies:
		var body: Node3D = _anim_bodies[target]
		body.visible = true
		var anim_player := Node3DSearch.find_anim_player(body)
		if anim_player:
			var list := anim_player.get_animation_list()
			if not list.is_empty():
				var anim_name := list[0]
				var anim := anim_player.get_animation(anim_name)
				if anim:
					anim.loop_mode = Animation.LOOP_LINEAR
				anim_player.play(anim_name)

func current_anim() -> String:
	return _anim_current
