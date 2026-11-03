class_name WorldYounAppearance
extends RefCounted

## Cuerpo visual de WorldYoun: instancia las escenas idle/walk/run (o el mesh
## estático si no hay ninguna) de `youn_data`, les aplica el material de
## textura si corresponde, y cambia cuál cuerpo está visible/animando. No
## sabe nada de IA, diálogo ni combate — `host` es el WorldYoun dueño
## exclusivo de esta instancia.

var host: WorldYoun
var _bodies := YounAnimBodies.new()

func _init(p_host: WorldYoun) -> void:
	host = p_host

## Instancia los cuerpos de `host.youn_data` dentro de `host.body_root`.
func setup() -> void:
	var youn_data := host.youn_data
	var mat: StandardMaterial3D = YounModelBuilder.material_for(youn_data)

	for key in ["idle", "walk", "run"]:
		var packed: PackedScene = youn_data.get("scene_" + key)
		if not packed:
			continue
		var body: Node3D = packed.instantiate()
		body.scale = Vector3.ONE * youn_data.mesh_scale
		body.position.y = 0.0
		body.rotation.y = youn_data.mesh_rotation_y
		body.visible = false
		YounModelBuilder.apply_material(body, mat)
		host.body_root.add_child(body)
		_bodies.register(key, body)

	if _bodies.is_empty() and youn_data.mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = youn_data.mesh
		mi.scale = Vector3.ONE * youn_data.mesh_scale
		mi.position.y = youn_data.mesh_y_offset
		YounModelBuilder.apply_material(mi, mat)
		host.body_root.add_child(mi)
	else:
		switch_anim("idle")

func switch_anim(key: String) -> void:
	_bodies.switch_to(key)
