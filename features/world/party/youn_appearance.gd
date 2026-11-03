class_name YounAppearance
extends RefCounted

## Cuerpo visual del compañero: instancia las escenas idle/walk/run/... de
## youn_data (o un modelo de primitivas si no trae ninguna) y cambia cuál
## cuerpo está visible/animando. No sabe nada de seguimiento ni de la burbuja
## de emociones — host es el Youn3D dueño exclusivo de esta instancia.

const PlaceholderModel := preload("res://features/world/party/placeholder_model.gd")
const DebugLog := preload("res://shared/debug_logging.gd")

var host: Youn3D
var _bodies := YounAnimBodies.new()

func _init(p_host: Youn3D) -> void:
	host = p_host

func load_model(data: YounData) -> void:
	_bodies.clear()

	var mat: StandardMaterial3D = YounModelBuilder.material_for(data)

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
		YounModelBuilder.apply_material(body, mat)
		_bodies.register(key, body)

	# Youn sin modelo todavía: uno de primitivas (PlaceholderModel), para que se vea.
	if _bodies.is_empty():
		var placeholder: Node3D = PlaceholderModel.build(data)
		placeholder.visible = false
		host.add_child(placeholder)
		_bodies.register("idle", placeholder)
	if DebugLog.verbose_enabled():
		print("[YounAppearance] Cuerpos cargados: %s" % _bodies.keys())
	switch_anim("idle")

func switch_anim(anim_key: String) -> void:
	_bodies.switch_to(anim_key)

func current_anim() -> String:
	return _bodies.current()
