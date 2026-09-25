class_name CardScaling
extends RefCounted

## De dónde salen las estadísticas con las que se calculan las cartas del jugador.

## Las estadísticas actuales de la partida; si todavía no hay (p. ej. combate
## abierto directo desde el editor), la base del Youn del grupo.
static func player_stats() -> Dictionary:
	var save: PlayerSaveData = GameState.player_save
	if save != null and not save.youn_stats.is_empty():
		return save.youn_stats
	var youn = PartyManager.youn
	if is_instance_valid(youn) and youn.youn_data != null and youn.youn_data.base_stats != null:
		return youn.youn_data.base_stats.to_dict()
	return {}

## Las líneas de una mitad ya calculadas para el jugador.
static func resolve_lines(lines: Array, stats: Dictionary) -> Array[CardActionLine]:
	var result: Array[CardActionLine] = []
	for line in lines:
		if line != null:
			result.append((line as CardActionLine).resolved(stats))
	return result
