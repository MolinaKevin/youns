class_name Node3DSearch
extends RefCounted

## Recorrido recursivo de un árbol de nodos instanciado (modelo de Youn,
## actor de combate, etc.) para encontrar sus mallas o su AnimationPlayer.
## Estaba copiado igual en youn_3d.gd, combat_actor_view.gd,
## evolution_scene.gd y world_youn_appearance.gd.
static func find_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(find_meshes(child))
	return result

static func find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := find_anim_player(child)
		if found:
			return found
	return null
