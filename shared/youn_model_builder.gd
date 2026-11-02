class_name YounModelBuilder
extends RefCounted

## Instancia el modelo 3D de un YounData para una cinemática: escala, textura
## y la primera animación del AnimationPlayer en loop. Comparte
## NewGameCeremony (partida nueva) y NewWorldWelcome (bienvenida al mundo),
## que antes repetían este mismo bloque con parámetros distintos.

static func instantiate(data: YounData, scene: PackedScene, scale_multiplier: float = 1.0, animation_speed: float = 1.0) -> Node3D:
	if scene == null:
		return null
	var model := scene.instantiate() as Node3D
	if model == null:
		return null
	model.scale = Vector3.ONE * data.mesh_scale * scale_multiplier
	apply_material(model, material_for(data))
	var animation_player := Node3DSearch.find_anim_player(model)
	if animation_player != null:
		animation_player.speed_scale = animation_speed
		var animations := animation_player.get_animation_list()
		if not animations.is_empty():
			var animation := animation_player.get_animation(animations[0])
			if animation != null:
				animation.loop_mode = Animation.LOOP_LINEAR
			animation_player.play(animations[0])
	return model

## Material con la textura de `data`, o null si no tiene (no agregar
## material_override en ese caso). Comparten esta construcción YounAppearance
## y WorldYounAppearance, que aplican el mismo material a varios cuerpos.
static func material_for(data: YounData) -> StandardMaterial3D:
	if data.texture == null:
		return null
	var material := StandardMaterial3D.new()
	material.albedo_texture = data.texture
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

## Aplica `material` (si no es null) a todos los meshes de `model`.
static func apply_material(model: Node3D, material: StandardMaterial3D) -> void:
	if material == null:
		return
	for mesh in Node3DSearch.find_meshes(model):
		mesh.material_override = material
