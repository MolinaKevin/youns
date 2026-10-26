class_name WorldCombatContext
extends RefCounted

## Datos que existen sólo entre iniciar un combate desde el mundo y volver a
## éste. No se guardan: al cerrar el juego no hay una transición pendiente.

var active := false
var return_position := Vector3.ZERO
var world_enemy_id := ""
var wild_youn_data: YounData
var biome: BiomeData


func begin(position: Vector3, enemy_id: String, youn_data: YounData, combat_biome: BiomeData) -> void:
	active = true
	return_position = position
	world_enemy_id = enemy_id
	wild_youn_data = youn_data
	biome = combat_biome


## El combate toma el dato al inicializarse. El resto del contexto sigue vivo
## hasta volver al mundo, para poder reubicar al grupo y resolver al enemigo.
func take_wild_youn_data() -> YounData:
	var result := wild_youn_data
	wild_youn_data = null
	return result


func set_preview_youn(data: YounData) -> void:
	wild_youn_data = data


## Al volver de un combate que arrancó un enemigo salvaje del mundo: lo busca
## por el grupo "world_enemy" + world_enemy_id y le avisa que el jugador
## ganó (para que se vaya con su loot). Limpia el contexto al terminar.
func resolve_victory(tree: SceneTree) -> void:
	if not active or world_enemy_id == "":
		return
	for enemy in tree.get_nodes_in_group("world_enemy"):
		if enemy.has_method("handle_player_victory") and enemy.get("world_enemy_id") == world_enemy_id:
			enemy.handle_player_victory(return_position)
			break
	clear()


func clear() -> void:
	active = false
	return_position = Vector3.ZERO
	world_enemy_id = ""
	wild_youn_data = null
	biome = null
