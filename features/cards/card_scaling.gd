class_name CardScaling
extends RefCounted

## De dónde salen las estadísticas con las que se calculan las cartas del jugador.

## Las estadísticas actuales de la partida más el peso ("peso"); si todavía no
## hay (p. ej. combate abierto directo desde el editor), la base del Youn del grupo.
static func player_stats() -> Dictionary:
	var save: PlayerSaveData = GameState.player_save
	if save != null and not save.youn_stats.is_empty():
		var stats: Dictionary = save.youn_stats.duplicate()
		stats["peso"] = save.weight
		return stats
	var youn = PartyManager.youn
	if is_instance_valid(youn) and youn.youn_data != null and youn.youn_data.base_stats != null:
		var stats: Dictionary = youn.youn_data.base_stats.to_dict()
		stats["peso"] = youn.youn_data.base_weight
		return stats
	return {}

## Las líneas de una mitad ya calculadas para el jugador.
static func resolve_lines(lines: Array, stats: Dictionary) -> Array[CardActionLine]:
	var result: Array[CardActionLine] = []
	for line in lines:
		if line != null:
			result.append((line as CardActionLine).resolved(stats))
	return result
